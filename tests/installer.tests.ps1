#requires -Version 5.1
[CmdletBinding()]
param([string]$WorkRoot = [System.IO.Path]::GetTempPath())
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repository = Split-Path $PSScriptRoot -Parent
$installer = Join-Path $repository 'install.ps1'
$testRoot = Join-Path $WorkRoot ('chinchilla-tests-' + [Guid]::NewGuid().ToString('N'))
[System.IO.Directory]::CreateDirectory($testRoot) | Out-Null
function Assert([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}
function Expect-Failure([scriptblock]$Action, [string]$Message) {
    $failed = $false
    try { & $Action | Out-Null } catch { $failed = $true }
    Assert $failed $Message
}

$configuration = Join-Path $testRoot 'custom home'
$pet = Join-Path $configuration 'pets\chinchilla'
$backups = Join-Path $configuration 'pets\.chinchilla-backups'
& $installer -CodexHome $configuration
Assert ((Get-FileHash (Join-Path $pet 'spritesheet.webp')).Hash -eq (Get-FileHash (Join-Path $repository 'spritesheet.webp')).Hash) 'Fresh installation differs from package.'
& $installer -CodexHome $configuration
Assert (-not (Test-Path $backups)) 'Identical reinstall created an unnecessary backup.'

# An older installation may contain additional user-owned files.
$oldJson = '{"id":"chinchilla","displayName":"Original","spritesheetPath":"spritesheet.webp"}'
[System.IO.File]::WriteAllText((Join-Path $pet 'pet.json'), $oldJson)
[System.IO.File]::WriteAllText((Join-Path $pet 'notes.txt'), 'Preserve this file.')
& $installer -CodexHome $configuration
$saved = @(Get-ChildItem -LiteralPath $backups -Directory)
Assert ($saved.Count -eq 1) 'Upgrade did not create exactly one backup.'
Assert ([System.IO.File]::ReadAllText((Join-Path $saved[0].FullName 'pet.json')) -eq $oldJson) 'Backup metadata changed.'
Assert (Test-Path (Join-Path $saved[0].FullName 'notes.txt')) 'Additional user file was not backed up.'
& $installer -CodexHome $configuration -RestoreBackup $saved[0].Name
Assert ([System.IO.File]::ReadAllText((Join-Path $pet 'pet.json')) -eq $oldJson) 'Restore did not recover original metadata.'
Assert (Test-Path (Join-Path $pet 'notes.txt')) 'Restore lost the additional user file.'
Assert (@(Get-ChildItem -LiteralPath $backups -Directory).Count -eq 1) 'Restore did not preserve the replaced installation.'

# Reject corruption before changing an existing installation.
$badPackage = Join-Path $testRoot 'corrupt-package'
[System.IO.Directory]::CreateDirectory($badPackage) | Out-Null
foreach ($name in @('install.ps1','checksums.json','pet.json','spritesheet.webp')) {
    Copy-Item -LiteralPath (Join-Path $repository $name) -Destination (Join-Path $badPackage $name)
}
[System.IO.File]::AppendAllText((Join-Path $badPackage 'spritesheet.webp'), 'corruption')
Expect-Failure { & (Join-Path $badPackage 'install.ps1') -CodexHome $configuration } 'Corrupt package was accepted.'
Assert ([System.IO.File]::ReadAllText((Join-Path $pet 'pet.json')) -eq $oldJson) 'Failed validation modified the installation.'
Expect-Failure { & $installer -CodexHome $configuration -RestoreBackup '..\outside' } 'Backup path traversal was accepted.'
Expect-Failure { & $installer -CodexHome $configuration -RestoreBackup 'chinchilla-20000101-000000-00000000' } 'Missing backup was accepted.'

$linkedHome = Join-Path $testRoot 'linked-home'
New-Item -ItemType Junction -Path $linkedHome -Target $configuration | Out-Null
Expect-Failure { & $installer -CodexHome $linkedHome } 'A junction destination was accepted.'
Assert (Test-Path (Join-Path $pet 'notes.txt')) 'Junction test modified the original installation.'
Write-Output "PASS: fresh install, repeat install, upgrade, full backup, restore, corruption rejection, path validation, and junction rejection. Test artifacts: $testRoot"
