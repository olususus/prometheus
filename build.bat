@echo off
REM Quick build script for Prometheus
REM Double-click to build with default settings

echo.
echo ===================================
echo Prometheus Quick Build
echo ===================================
echo.

REM Check if PowerShell is available
where pwsh >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    echo Using PowerShell Core...
    pwsh -ExecutionPolicy Bypass -File "%~dp0build.ps1" %*
) else (
    echo Using Windows PowerShell...
    powershell -ExecutionPolicy Bypass -File "%~dp0build.ps1" %*
)

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Build failed! Press any key to exit...
    pause >nul
    exit /b %ERRORLEVEL%
)

echo.
echo Build completed! Press any key to exit...
pause >nul
