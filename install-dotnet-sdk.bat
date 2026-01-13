@echo off
REM Install .NET 8 SDK for building the patcher project
REM This script downloads and installs the .NET 8 SDK

echo.
echo ===================================
echo .NET 8 SDK Installer
echo ===================================
echo.

REM Check if already installed
where dotnet >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    echo Checking .NET SDK version...
    dotnet --version
    echo.
    echo .NET SDK is already installed!
    echo If you're having build issues, you may need to install .NET 8 specifically.
    echo.
    choice /C YN /M "Do you want to continue with the installation anyway?"
    if errorlevel 2 goto :end
)

echo.
echo This will download and install the .NET 8 SDK (x64).
echo Download size: ~200 MB
echo.
choice /C YN /M "Do you want to continue?"
if errorlevel 2 goto :end

echo.
echo Downloading .NET 8 SDK installer...

REM Use PowerShell to download the installer
powershell -Command "& {Invoke-WebRequest -Uri 'https://aka.ms/dotnet/8.0/dotnet-sdk-win-x64.exe' -OutFile '%TEMP%\dotnet-sdk-8-installer.exe'}"

if not exist "%TEMP%\dotnet-sdk-8-installer.exe" (
    echo.
    echo ERROR: Download failed!
    echo Please download manually from: https://dotnet.microsoft.com/download/dotnet/8.0
    pause
    exit /b 1
)

echo.
echo Running installer...
echo Please follow the installation wizard.
echo.

start /wait "%TEMP%\dotnet-sdk-8-installer.exe"

REM Clean up
del "%TEMP%\dotnet-sdk-8-installer.exe" 2>nul

echo.
echo Installation complete!
echo.
echo Verifying installation...
dotnet --version

if %ERRORLEVEL% EQU 0 (
    echo.
    echo SUCCESS: .NET SDK is now installed!
    echo You can now run build.bat to build the project.
) else (
    echo.
    echo WARNING: Could not verify .NET SDK installation.
    echo You may need to restart your command prompt or computer.
)

:end
echo.
pause
