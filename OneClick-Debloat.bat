@echo off
setlocal
set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%PS%" (
    echo Windows PowerShell 5.1 was not found. This tool requires Windows 10 or 11.
    pause
    exit /b 1
)
if not exist "%~dp0WinDebloat.ps1" (
    echo WinDebloat.ps1 is missing next to this file.
    pause
    exit /b 1
)
"%PS%" -NoProfile -ExecutionPolicy Bypass -Command "if ($PSVersionTable.PSVersion.Major -lt 5) { exit 1 }"
if errorlevel 1 (
    echo Windows PowerShell 5.1 or newer is required.
    pause
    exit /b 1
)
net session >nul 2>&1
if not "%errorlevel%"=="0" (
    "%PS%" -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)
"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0WinDebloat.ps1" %*
echo.
echo Logs are in the logs folder next to this file.
pause
