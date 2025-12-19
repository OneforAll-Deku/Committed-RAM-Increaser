@echo off
cd /d "%~dp0"

net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Requesting Administrator privileges...
    powershell -Command "Start-Process cmd -ArgumentList '/c, ""%~f0""' -Verb RunAs"
    exit /b
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0RamIncreaserScript.ps1"

if %errorLevel% neq 0 (
    echo.
    echo Script exited with error code %errorLevel%.
    pause
)
