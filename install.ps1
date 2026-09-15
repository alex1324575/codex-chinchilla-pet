#requires -Version 5.1
<#
.SYNOPSIS
Installs Chinchilla for Codex, preserving an existing installation as a backup.
#>
[CmdletBinding()]
param(
    [string]$CodexHome,
    [ValidatePattern('^chinchilla-[0-9]{8}-[0-9]{6}-[a-f0-9]{8}$')]
    [string]$RestoreBackup
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-PlainPath([string]$Path) {
    $cursor = [System.IO.Path]::GetFullPath($Path)
    while ($cursor) {
        if (Test-Path -LiteralPath $cursor) {
            $item = Get-Item -LiteralPath $cursor -Force
            if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
                throw "Symbolic links and junctions are not supported: $cursor"
            }
        }
        $parent = [System.IO.Directory]::GetParent($cursor)
        if ($null -eq $parent) { break }
        $cursor = $parent.FullName
    }
}

function Assert-PlainTree([string]$Path) {
    Assert-PlainPath $Path
    if (Test-Path -LiteralPath $Path) {
        if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
            throw "Expected a directory: $Path"
        }
        foreach ($entry in Get-ChildItem -LiteralPath $Path -Force -Recurse) {
            if ($entry.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
                throw "Backup cannot include symbolic links or junctions: $($entry.FullName)"
            }
        }
    }
}

if (-not $CodexHome) {
    if ($env:CODEX_HOME) { $CodexHome = $env:CODEX_HOME }
    else { $CodexHome = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.codex' }
}
$configurationRoot = [System.IO.Path]::GetFullPath($CodexHome)
$petsRoot = Join-Path $configurationRoot 'pets'
$destination = Join-Path $petsRoot 'chinchilla'
$backupRoot = Join-Path $petsRoot '.chinchilla-backups'
Assert-PlainTree $destination
Assert-PlainTree $backupRoot

if ($RestoreBackup) {
    $incoming = Join-Path $backupRoot $RestoreBackup
    if (-not (Test-Path -LiteralPath $incoming -PathType Container)) {
        throw "Backup not found: $incoming"
    }
    Assert-PlainTree $incoming
    if (-not (Test-Path -LiteralPath (Join-Path $incoming 'pet.json') -PathType Leaf)) {
        throw 'The selected backup is not a pet installation.'
    }
} else {
    $checksums = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot 'checksums.json') | ConvertFrom-Json
    foreach ($name in @('pet.json', 'spritesheet.webp')) {
        $source = Join-Path $PSScriptRoot $name
        Assert-PlainPath $source
        $expected = $checksums.$name
        if ($expected -notmatch '^[a-fA-F0-9]{64}$' -or
            (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -ne $expected) {
            throw "Package checksum mismatch: $name. Download and extract the release again."
        }
    }
    $metadata = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot 'pet.json') | ConvertFrom-Json
    if ($metadata.id -ne 'chinchilla' -or $metadata.spriteVersionNumber -ne 2 -or
        $metadata.spritesheetPath -ne 'spritesheet.webp') {
        throw 'This installer requires the Chinchilla v2 package.'
    }
    if (Test-Path -LiteralPath $destination -PathType Container) {
        $matches = $true
        foreach ($name in @('pet.json', 'spritesheet.webp')) {
            $installed = Join-Path $destination $name
            if (-not (Test-Path -LiteralPath $installed -PathType Leaf) -or
                (Get-FileHash -LiteralPath $installed -Algorithm SHA256).Hash -ne $checksums.$name) {
                $matches = $false
            }
        }
        if ($matches) {
            Write-Output "Chinchilla is already up to date: $destination"
            return
        }
    }
    [System.IO.Directory]::CreateDirectory($petsRoot) | Out-Null
    $incoming = Join-Path $petsRoot ('.chinchilla-stage-' + [Guid]::NewGuid().ToString('N'))
    [System.IO.Directory]::CreateDirectory($incoming) | Out-Null
    foreach ($name in @('pet.json', 'spritesheet.webp')) {
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination (Join-Path $incoming $name)
        if ((Get-FileHash -LiteralPath (Join-Path $incoming $name) -Algorithm SHA256).Hash -ne $checksums.$name) {
            throw "Staged file verification failed; existing installation is unchanged. Staging directory: $incoming"
        }
    }
}

# All directory moves stay within the resolved pets directory. No files are deleted.
foreach ($path in @($destination, $incoming, $backupRoot)) {
    if (-not ([System.IO.Path]::GetFullPath($path)).StartsWith($petsRoot + [System.IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Operation outside the pets directory refused: $path"
    }
    Assert-PlainPath $path
}
$savedBackup = $null
if (Test-Path -LiteralPath $destination) {
    [System.IO.Directory]::CreateDirectory($backupRoot) | Out-Null
    $backupName = 'chinchilla-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0, 8)
    $savedBackup = Join-Path $backupRoot $backupName
    [System.IO.Directory]::Move($destination, $savedBackup)
}
try {
    [System.IO.Directory]::Move($incoming, $destination)
} catch {
    if ($savedBackup -and -not (Test-Path -LiteralPath $destination)) {
        [System.IO.Directory]::Move($savedBackup, $destination)
    }
    throw
}
if ($RestoreBackup) { Write-Output "Restored Chinchilla: $destination" }
else { Write-Output "Installed Chinchilla: $destination" }
if ($savedBackup) {
    Write-Output "Previous installation preserved: $savedBackup"
    Write-Output "To restore it, run install.ps1 with -RestoreBackup '$backupName' and the same -CodexHome, if specified."
}
Write-Output 'Select Chinchilla in the Codex pet picker. Reopen Codex if needed.'
