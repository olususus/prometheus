#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Build script for Prometheus project
.DESCRIPTION
    Builds both C++ (prometheus) and C# (patcher) projects and combines output
.PARAMETER Configuration
    Build configuration (Release or Debug). Default: Release
.PARAMETER Platform
    Build platform (x64 or x86). Default: x64
.PARAMETER SkipCpp
    Skip building the C++ project
.PARAMETER SkipCSharp
    Skip building the C# patcher project
.PARAMETER SkipCopy
    Skip copying DLLs to final output directory
.PARAMETER OutputDir
    Custom output directory. Default: build\output
.PARAMETER Clean
    Clean before building
.PARAMETER Verbose
    Enable verbose output
.EXAMPLE
    .\build.ps1
    .\build.ps1 -Configuration Debug
    .\build.ps1 -Clean -Verbose
#>

param(
    [ValidateSet('Release', 'Debug')]
    [string]$Configuration = 'Release',
    
    [ValidateSet('x64', 'x86')]
    [string]$Platform = 'x64',
    
    [switch]$SkipCpp,
    [switch]$SkipCSharp,
    [switch]$SkipCopy,
    
    [string]$OutputDir = "build\output",
    
    [switch]$Clean,
    [switch]$Verbose
)

# Configuration
$ErrorActionPreference = "Stop"
$ScriptDir = $PSScriptRoot
$SolutionFile = Join-Path $ScriptDir "testinj.sln"
$PatcherProject = Join-Path $ScriptDir "patcher\patcher.csproj"
$CppOutputDir = Join-Path $ScriptDir "$Platform\$Configuration"
$CSharpOutputDir = Join-Path $ScriptDir "patcher\bin\$Configuration\net8.0-windows"
$FinalOutputDir = Join-Path $ScriptDir $OutputDir
$script:MSBuildPath = $null
$script:DotNetSdk = $null

# Colors for output
function Write-Step {
    param([string]$Message)
    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "? $Message" -ForegroundColor Green
}

function Write-Error {
    param([string]$Message)
    Write-Host "? $Message" -ForegroundColor Red
}

function Write-Info {
    param([string]$Message)
    Write-Host "  $Message" -ForegroundColor Gray
}

# Find MSBuild in Visual Studio installations
function Find-MSBuild {
    # Try to get from PATH first
    $msbuild = Get-Command msbuild -ErrorAction SilentlyContinue
    if ($msbuild) {
        return $msbuild.Source
    }
    
    # Search in common Visual Studio installation paths
    $vsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    
    if (Test-Path $vsWhere) {
        Write-Info "Using vswhere to locate MSBuild..."
        $vsPath = & $vsWhere -latest -requires Microsoft.Component.MSBuild -property installationPath
        if ($vsPath) {
            # Try different MSBuild locations
            $msbuildPaths = @(
                "$vsPath\MSBuild\Current\Bin\MSBuild.exe",
                "$vsPath\MSBuild\Current\Bin\amd64\MSBuild.exe",
                "$vsPath\Msbuild\15.0\Bin\MSBuild.exe"
            )
            
            foreach ($path in $msbuildPaths) {
                if (Test-Path $path) {
                    return $path
                }
            }
        }
    }
    
    # Fallback: search common installation directories
    $searchPaths = @(
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe",
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\Professional\MSBuild\Current\Bin\MSBuild.exe",
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\Enterprise\MSBuild\Current\Bin\MSBuild.exe",
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\Professional\MSBuild\Current\Bin\MSBuild.exe",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\Enterprise\MSBuild\Current\Bin\MSBuild.exe",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe",
        "${env:ProgramFiles}\Microsoft Visual Studio\2019\Community\MSBuild\Current\Bin\MSBuild.exe",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\Community\MSBuild\Current\Bin\MSBuild.exe"
    )
    
    foreach ($path in $searchPaths) {
        if (Test-Path $path) {
            return $path
        }
    }
    
    return $null
}

# Find .NET SDK
function Find-DotNetSdk {
    # Check for dotnet command
    $dotnet = Get-Command dotnet -ErrorAction SilentlyContinue
    if ($dotnet) {
        try {
            $version = & dotnet --version 2>$null
            if ($version) {
                return @{
                    Path = $dotnet.Source
                    Version = $version
                    Found = $true
                }
            }
        }
        catch {
            # dotnet command exists but failed to run
        }
    }
    
    # Check for .NET SDK in common locations
    $sdkPaths = @(
        "$env:ProgramFiles\dotnet\sdk",
        "${env:ProgramFiles(x86)}\dotnet\sdk"
    )
    
    foreach ($path in $sdkPaths) {
        if (Test-Path $path) {
            $versions = Get-ChildItem $path -Directory | Sort-Object Name -Descending
            if ($versions) {
                return @{
                    Path = $path
                    Version = $versions[0].Name
                    Found = $true
                }
            }
        }
    }
    
    return @{
        Found = $false
    }
}

# Check for required tools
function Test-Prerequisites {
    Write-Step "Checking prerequisites..."
    
    $hasErrors = $false
    
    # Check for MSBuild
    $script:MSBuildPath = Find-MSBuild
    if (-not $script:MSBuildPath) {
        Write-Error "MSBuild not found. Please install Visual Studio 2022 or Build Tools."
        Write-Info "Download from: https://visualstudio.microsoft.com/downloads/"
        $hasErrors = $true
    } else {
        Write-Success "MSBuild found: $script:MSBuildPath"
    }
    
    # Check for .NET SDK
    $script:DotNetSdk = Find-DotNetSdk
    if (-not $script:DotNetSdk.Found) {
        Write-Error ".NET 8 SDK not found. Required for C# patcher project."
        Write-Info "Download from: https://dotnet.microsoft.com/download/dotnet/8.0"
        Write-Info "Or install '.NET desktop development' workload in Visual Studio Installer"
        $hasErrors = $true
    } else {
        Write-Success ".NET SDK found: $($script:DotNetSdk.Version)"
    }
    
    # Check for vcpkg
    $vcpkgExe = Join-Path $ScriptDir "external\vcpkg\vcpkg.exe"
    if (-not (Test-Path $vcpkgExe)) {
        Write-Error "vcpkg.exe not found. Please run: external\vcpkg\bootstrap-vcpkg.bat"
        $hasErrors = $true
    } else {
        Write-Success "vcpkg found"
    }
    
    # Check solution file
    if (-not (Test-Path $SolutionFile)) {
        Write-Error "Solution file not found: $SolutionFile"
        $hasErrors = $true
    }
    
    if ($hasErrors) {
        throw "Prerequisites check failed. Please fix the errors above."
    }
}

# Clean build artifacts
function Invoke-Clean {
    Write-Step "Cleaning build artifacts..."
    
    $dirsToClean = @(
        "$Platform\$Configuration",
        "patcher\bin\$Configuration",
        "patcher\obj\$Configuration",
        "prometheus\$Platform\$Configuration",
        "prometheus\obj\$Configuration",
        $FinalOutputDir
    )
    
    foreach ($dir in $dirsToClean) {
        $fullPath = Join-Path $ScriptDir $dir
        if (Test-Path $fullPath) {
            Write-Info "Removing: $dir"
            Remove-Item -Path $fullPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    Write-Success "Clean completed"
}

# Build C++ project
function Build-CppProject {
    Write-Step "Building C++ project (prometheus)..."
    Write-Info "Configuration: $Configuration | Platform: $Platform"
    
    $msbuildArgs = @(
        "`"$SolutionFile`"",
        "/t:prometheus",
        "/p:Configuration=$Configuration",
        "/p:Platform=$Platform",
        "/m"
    )
    
    if ($Verbose) {
        $msbuildArgs += "/v:detailed"
    } else {
        $msbuildArgs += "/v:minimal"
    }
    
    Write-Info "Running: $script:MSBuildPath $($msbuildArgs -join ' ')"
    
    & $script:MSBuildPath $msbuildArgs
    
    if ($LASTEXITCODE -ne 0) {
        throw "C++ build failed with exit code $LASTEXITCODE"
    }
    
    # Verify output
    $prometheusLib = Join-Path $CppOutputDir "prometheus.dll"
    if (-not (Test-Path $prometheusLib)) {
        throw "prometheus.dll not found in output directory: $CppOutputDir"
    }
    
    Write-Success "C++ build completed"
    Write-Info "Output: $CppOutputDir"
}

# Build C# project
function Build-CSharpProject {
    Write-Step "Building C# project (patcher)..."
    Write-Info "Configuration: $Configuration"
    
    Write-Info "Publishing self-contained patcher..."
    
    # Use dotnet publish for self-contained single-file
    $publishArgs = @(
        "publish",
        "`"$PatcherProject`"",
        "-c", "$Configuration",
        "-r", "win-x64",
        "--self-contained",
        "-p:PublishSingleFile=true",
        "-p:EnableCompressionInSingleFile=true",
        "-o", "`"$CSharpOutputDir`""
    )
    
    if ($Verbose) {
        $publishArgs += "-v", "detailed"
    } else {
        $publishArgs += "-v", "minimal"
    }
    
    Write-Info "Running: dotnet $($publishArgs -join ' ')"
    
    & dotnet $publishArgs
    
    if ($LASTEXITCODE -ne 0) {
        throw "C# publish failed with exit code $LASTEXITCODE"
    }
    
    # Verify output
    $patcherExe = Join-Path $CSharpOutputDir "patcher.exe"
    if (-not (Test-Path $patcherExe)) {
        throw "patcher.exe not found in output directory: $CSharpOutputDir"
    }
    
    Write-Success "C# build completed (self-contained, single-file)"
    Write-Info "Output: $CSharpOutputDir"
}

# Copy all files to final output directory
function Copy-BuildOutputs {
    Write-Step "Copying build outputs to final directory..."
    Write-Info "Destination: $FinalOutputDir"
    
    # Create output directory
    if (-not (Test-Path $FinalOutputDir)) {
        New-Item -ItemType Directory -Path $FinalOutputDir -Force | Out-Null
    }
    
    # Copy C++ DLLs and PDBs
    if (Test-Path $CppOutputDir) {
        Write-Info "Copying C++ outputs..."
        $cppFiles = Get-ChildItem -Path $CppOutputDir -Filter "*.dll"
        $cppFiles += Get-ChildItem -Path $CppOutputDir -Filter "*.pdb"
        foreach ($file in $cppFiles) {
            Copy-Item -Path $file.FullName -Destination $FinalOutputDir -Force
            Write-Host "  + $($file.Name)" -ForegroundColor DarkGray
        }
    }
    
    # Copy C# outputs
    if (Test-Path $CSharpOutputDir) {
        Write-Info "Copying C# outputs..."
        $csharpFiles = Get-ChildItem -Path $CSharpOutputDir -Filter "patcher.*"
        foreach ($file in $csharpFiles) {
            Copy-Item -Path $file.FullName -Destination $FinalOutputDir -Force
            Write-Host "  + $($file.Name)" -ForegroundColor DarkGray
        }
    }
    
    Write-Success "Copy completed"
}

# Display summary
function Show-Summary {
    Write-Step "Build Summary"
    
    if (Test-Path $FinalOutputDir) {
        $files = Get-ChildItem -Path $FinalOutputDir -File | Sort-Object Extension, Name
        
        Write-Host "`nOutput files in: " -NoNewline
        Write-Host $FinalOutputDir -ForegroundColor Yellow
        Write-Host ""
        
        $totalSize = 0
        foreach ($file in $files) {
            $sizeKB = [math]::Round($file.Length / 1KB, 2)
            $totalSize += $file.Length
            
            $color = switch ($file.Extension) {
                ".exe" { "Green" }
                ".dll" { "Cyan" }
                ".pdb" { "DarkGray" }
                ".json" { "Yellow" }
                default { "White" }
            }
            
            Write-Host "  $($file.Name.PadRight(30)) " -NoNewline
            Write-Host "$sizeKB KB" -ForegroundColor $color
        }
        
        $totalMB = [math]::Round($totalSize / 1MB, 2)
        Write-Host "`nTotal: $($files.Count) files, $totalMB MB" -ForegroundColor White
    }
    
    Write-Host ""
    Write-Success "Build completed successfully!"
    Write-Host ""
}

# Main execution
try {
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    Write-Host ""
    Write-Host "?????????????????????????????????????????????????????????????" -ForegroundColor Cyan
    Write-Host "?         Prometheus Build Script                          ?" -ForegroundColor Cyan
    Write-Host "?????????????????????????????????????????????????????????????" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Configuration: $Configuration | Platform: $Platform" -ForegroundColor White
    Write-Host ""
    
    # Check prerequisites
    Test-Prerequisites
    
    # Clean if requested
    if ($Clean) {
        Invoke-Clean
    }
    
    # Build C++ project
    if (-not $SkipCpp) {
        Build-CppProject
    } else {
        Write-Info "Skipping C++ build (SkipCpp flag set)"
    }
    
    # Build C# project
    if (-not $SkipCSharp) {
        Build-CSharpProject
    } else {
        Write-Info "Skipping C# build (SkipCSharp flag set)"
    }
    
    # Copy outputs
    if (-not $SkipCopy) {
        Copy-BuildOutputs
    } else {
        Write-Info "Skipping copy (SkipCopy flag set)"
    }
    
    # Show summary
    $stopwatch.Stop()
    Show-Summary
    Write-Info "Total time: $($stopwatch.Elapsed.ToString('mm\:ss'))"
    
    exit 0
}
catch {
    Write-Host ""
    Write-Error "Build failed: $_"
    Write-Host ""
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    Write-Host ""
    exit 1
}
