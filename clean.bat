@echo off
REM Clean build artifacts

echo.
echo Cleaning build artifacts...
echo.

if exist "build" (
    echo Removing build directory...
    rmdir /s /q "build"
)

if exist "x64" (
    echo Removing x64 directory...
    rmdir /s /q "x64"
)

if exist "patcher\bin" (
    echo Removing patcher\bin...
    rmdir /s /q "patcher\bin"
)

if exist "patcher\obj" (
    echo Removing patcher\obj...
    rmdir /s /q "patcher\obj"
)

if exist "prometheus\x64" (
    echo Removing prometheus\x64...
    rmdir /s /q "prometheus\x64"
)

if exist "prometheus\obj" (
    echo Removing prometheus\obj...
    rmdir /s /q "prometheus\obj"
)

echo.
echo Clean completed!
echo.
pause
