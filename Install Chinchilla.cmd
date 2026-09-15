@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
set "chinchilla_exit=%ERRORLEVEL%"
echo.
pause
exit /b %chinchilla_exit%
