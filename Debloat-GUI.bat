@echo off
setlocal
set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%PS%" (
    echo Windows PowerShell 5.1 was not found. This tool requires Windows 10 or 11.
    pause
    exit /b 1
)
if not exist "%~dp0WinDebloat-GUI.ps1" (
    echo WinDebloat-GUI.ps1 is missing next to this file.
    pause
    exit /b 1
)
if not exist "%~dp0WinDebloat.ps1" (
    echo WinDebloat.ps1 is missing next to this file.
    pause
    exit /b 1
)
if not exist "%~dp0ui\WinDebloatUi.cs" (
    echo ui\WinDebloatUi.cs is missing. Download the full release folder, not only the batch file.
    pause
    exit /b 1
)
if not exist "%~dp0assets\icons" (
    echo The assets folder is missing. Download the full release folder, not only the batch file.
    pause
    exit /b 1
)
"%PS%" -NoProfile -ExecutionPolicy Bypass -Command "if ($PSVersionTable.PSVersion.Major -lt 5) { exit 1 }"
if errorlevel 1 (
    echo Windows PowerShell 5.1 or newer is required.
    pause
    exit /b 1
)
start "" "%PS%" -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0WinDebloat-GUI.ps1"
