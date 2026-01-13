# Prometheus Build System

This directory contains build scripts and configuration for the Prometheus project.

## Quick Start

### Windows (Easiest - Double Click!)
1. **Build everything**: Double-click **`build.bat`**
2. **Clean build**: Double-click **`clean.bat`** then **`build.bat`**

All your files will be in `build\output\` folder! ??

### PowerShell (More Control)
```powershell
# Simple build
.\build.ps1

# Clean build
.\build.ps1 -Clean

# Debug build
.\build.ps1 -Configuration Debug
```

## What Gets Built

The script automatically:
1. ? Checks all prerequisites (MSBuild, vcpkg, etc.)
2. ? Builds the C++ project (prometheus.dll + dependencies)
3. ? Builds the C# patcher (patcher.exe)
4. ? Copies everything to one place: `build\output\`
5. ? Shows you a nice summary

## Output Files

Find all your build artifacts in **`build\output\`**:

### Main Files
- **`patcher.exe`** - Your C# patcher application (148 KB)
- **`prometheus.dll`** - Main C++ library (~2.9 MB)

### Dependencies (from vcpkg)
- `brotlicommon.dll` (135 KB)
- `brotlidec.dll` (50 KB)  
- `bz2.dll` (75 KB)
- `freetype.dll` (675 KB)
- `libpng16.dll` (202 KB)
- `minhook.x64.dll` (23 KB)
- `zlib1.dll` (88 KB)

### Debug & Config
- `patcher.dll`, `patcher.deps.json`, `patcher.runtimeconfig.json`
- `*.pdb` files (debug symbols)

**Total**: ~24 MB

## Build Options

### Basic Usage
```powershell
# Build Release (default)
.\build.ps1

# Build Debug
.\build.ps1 -Configuration Debug

# Clean build
.\build.ps1 -Clean

# Verbose output
.\build.ps1 -Verbose
```

### Advanced Options
```powershell
# Skip C++ build (if already built)
.\build.ps1 -SkipCpp

# Skip C# build
.\build.ps1 -SkipCSharp

# Build but don't copy to output directory
.\build.ps1 -SkipCopy

# Custom output directory
.\build.ps1 -OutputDir "releases\v1.0"

# Build for x86 instead of x64
.\build.ps1 -Platform x86
```

### Combined Examples
```powershell
# Clean Debug build with verbose output
.\build.ps1 -Configuration Debug -Clean -Verbose

# Release build, skip C++, custom output
.\build.ps1 -SkipCpp -OutputDir "releases\v1.0"
```

## Configuration File

Edit **`build.config.json`** to change defaults:
```json
{
  "buildConfig": {
    "defaultConfiguration": "Release",
    "defaultPlatform": "x64",
    "outputDirectory": "build/output",
    "cleanBeforeBuild": false,
    "verboseOutput": false
  }
}
```

## Prerequisites

### Required
1. **Visual Studio 2022** or **Build Tools for Visual Studio 2022**
2. **vcpkg** (included) - Initialize by running:
   ```cmd
   external\vcpkg\bootstrap-vcpkg.bat
   ```
3. **.NET 8 SDK**

### First Time Setup
```cmd
REM 1. Initialize vcpkg
external\vcpkg\bootstrap-vcpkg.bat

REM 2. Install dependencies
cd prometheus
..\external\vcpkg\vcpkg.exe install --triplet x64-windows

REM 3. Build!
cd ..
build.bat
```

## Troubleshooting

### "MSBuild not found"
**Solution**: Install [Visual Studio 2022](https://visualstudio.microsoft.com/) or [Build Tools for Visual Studio 2022](https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022)

### "vcpkg.exe not found"  
**Solution**: Run `external\vcpkg\bootstrap-vcpkg.bat`

### Build fails with missing dependencies
**Solution**: Install vcpkg dependencies:
```powershell
cd prometheus
..\external\vcpkg\vcpkg.exe install --triplet x64-windows
cd ..
```

### "prometheus.dll not found" after build
**Solution**: 
1. Run `clean.bat`
2. Run `build.bat` again
3. If still fails, check build logs with: `.\build.ps1 -Verbose`

### Build is slow the first time
**This is normal!** The first build compiles all vcpkg dependencies from source. Subsequent builds are much faster.

## Project Structure

```
prometheus/
??? build.ps1                 # Main build script (PowerShell)
??? build.bat                 # Windows batch wrapper (double-click me!)
??? clean.bat                 # Clean all build artifacts
??? build.config.json         # Build configuration
??? BUILD.md                  # This file
??? testinj.sln              # C++ solution
??? prometheus/              # C++ project
?   ??? prometheus.vcxproj
?   ??? vcpkg.json           # Dependencies
??? patcher/                 # C# project
?   ??? patcher.csproj
??? external/
?   ??? vcpkg/               # Package manager
??? build/                   # Build outputs
    ??? output/              # ? Your files are here! ?
```

## Quick Reference

| What do you want? | Command |
|-------------------|---------|
| Just build it! | Double-click `build.bat` |
| Clean everything | Double-click `clean.bat` |
| Clean + build | `.\build.ps1 -Clean` |
| Debug build | `.\build.ps1 -Configuration Debug` |
| See what's happening | `.\build.ps1 -Verbose` |
| Help! | `Get-Help .\build.ps1 -Detailed` |

## Tips & Tricks

- ?? First build takes ~5 minutes (vcpkg dependencies)
- ?? Subsequent builds take ~10 seconds
- ?? Use `-Clean` if you encounter strange errors
- ?? Use `-Verbose` to debug build issues
- ?? Check `build\output\` for all your files
- ?? You can rename/move the `build\output` folder anywhere
- ?? The build script auto-detects if you're missing tools

## What Changed from Original?

The build script fixed two bugs in the source code:
1. Fixed `*s_all_windows` ? `s_all_windows()` (it's a function, not a pointer)
2. Fixed `std::format` runtime format strings ? compile-time format strings

These fixes are already applied to your workspace files.
