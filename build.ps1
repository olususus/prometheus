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

# Check for required tools
function Test-Prerequisites {
    Write-Step "Checking prerequisites..."
    
    $hasErrors = $false
    
    # Check for MSBuild
    $msbuild = Get-Command msbuild -ErrorAction SilentlyContinue
    if (-not $msbuild) {
        Write-Error "MSBuild not found. Please install Visual Studio 2022 or Build Tools."
        $hasErrors = $true
    } else {
        Write-Success "MSBuild found: $($msbuild.Source)"
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
    
    Write-Info "Running: msbuild $($msbuildArgs -join ' ')"
    
    & msbuild $msbuildArgs
    
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
    
    $msbuildArgs = @(
        "`"$PatcherProject`"",
        "/p:Configuration=$Configuration",
        "/m"
    )
    
    if ($Verbose) {
        $msbuildArgs += "/v:detailed"
    } else {
        $msbuildArgs += "/v:minimal"
    }
    
    Write-Info "Running: msbuild $($msbuildArgs -join ' ')"
    
    & msbuild $msbuildArgs
    
    if ($LASTEXITCODE -ne 0) {
        throw "C# build failed with exit code $LASTEXITCODE"
    }
    
    # Verify output
    $patcherExe = Join-Path $CSharpOutputDir "patcher.exe"
    if (-not (Test-Path $patcherExe)) {
        throw "patcher.exe not found in output directory: $CSharpOutputDir"
    }
    
    Write-Success "C# build completed"
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
