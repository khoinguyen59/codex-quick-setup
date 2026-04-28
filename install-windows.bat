@echo off
:: Batch file to run PowerShell script as Administrator
net session >nul 2>&1
if %errorLevel% == 0 (
    goto :run
) else (
    echo Dang yeu cau quyen Administrator...
    powershell -Command "Start-Process powershell -ArgumentList '-NoExit -ExecutionPolicy Bypass -NoProfile -File ""%~dp0install-windows.ps1""' -Verb RunAs"
    exit /B
)

:run
pushd "%CD%"
CD /D "%~dp0"
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "install-windows.ps1"
pause
