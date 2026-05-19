# ============================================================================
# Zeus Installer for Windows
# ============================================================================
# Installs Project Zeus by Red Robot Resource into a separate Windows client
# home so Zeus and Hermes Agent can run independently on the same machine.
#
# Usage:
#   irm https://raw.githubusercontent.com/RedRobot-Resource/project-zeus/main/scripts/install-zeus.ps1 | iex
#
# Or download and run:
#   .\install-zeus.ps1 -SkipSetup
# ============================================================================

param(
    [switch]$NoVenv,
    [switch]$SkipSetup,
    [string]$Branch = "main",
    [string]$ZeusHome = "$env:LOCALAPPDATA\Zeus",
    [string]$InstallDir = "$env:LOCALAPPDATA\Zeus\project-zeus"
)

$ErrorActionPreference = "Stop"

$RepoUrlHttps = "https://github.com/RedRobot-Resource/project-zeus.git"
$PythonVersion = "3.11"

function Write-Banner {
    Write-Host ""
    Write-Host "┌─────────────────────────────────────────────────────────┐" -ForegroundColor Red
    Write-Host "│                  ⚡ Zeus Installer                       │" -ForegroundColor Red
    Write-Host "├─────────────────────────────────────────────────────────┤" -ForegroundColor Red
    Write-Host "│        A Red Robot Resource Windows AI client.          │" -ForegroundColor Red
    Write-Host "│        Runs independently from Hermes Agent.            │" -ForegroundColor Red
    Write-Host "└─────────────────────────────────────────────────────────┘" -ForegroundColor Red
    Write-Host ""
}

function Write-Info { param([string]$Message) Write-Host "→ $Message" -ForegroundColor Cyan }
function Write-Success { param([string]$Message) Write-Host "✓ $Message" -ForegroundColor Green }
function Write-Warn { param([string]$Message) Write-Host "⚠ $Message" -ForegroundColor Yellow }
function Write-Err { param([string]$Message) Write-Host "✗ $Message" -ForegroundColor Red }

function Install-Uv {
    Write-Info "Checking for uv package manager..."
    if (Get-Command uv -ErrorAction SilentlyContinue) {
        $script:UvCmd = "uv"
        Write-Success "uv found ($(uv --version))"
        return
    }

    $uvPaths = @(
        "$env:USERPROFILE\.local\bin\uv.exe",
        "$env:USERPROFILE\.cargo\bin\uv.exe"
    )
    foreach ($uvPath in $uvPaths) {
        if (Test-Path $uvPath) {
            $script:UvCmd = $uvPath
            Write-Success "uv found at $uvPath"
            return
        }
    }

    Write-Info "Installing uv..."
    powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex" 2>&1 | Out-Null
    $env:Path = [Environment]::GetEnvironmentVariable("Path", "User") + ";" + [Environment]::GetEnvironmentVariable("Path", "Machine")
    if (Get-Command uv -ErrorAction SilentlyContinue) {
        $script:UvCmd = "uv"
        Write-Success "uv installed"
        return
    }
    throw "uv installed but was not found on PATH. Restart PowerShell and rerun this installer."
}

function Install-GitIfNeeded {
    if (Get-Command git -ErrorAction SilentlyContinue) {
        Write-Success "git found ($(git --version))"
        return
    }
    Write-Info "Installing Git with winget..."
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw "git is required and winget is unavailable. Install Git for Windows, then rerun."
    }
    winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements
    $env:Path = [Environment]::GetEnvironmentVariable("Path", "User") + ";" + [Environment]::GetEnvironmentVariable("Path", "Machine")
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw "git installed but was not found on PATH. Restart PowerShell and rerun."
    }
}

function Install-ZeusSource {
    New-Item -ItemType Directory -Force -Path $ZeusHome | Out-Null
    if (Test-Path "$InstallDir\.git") {
        Write-Info "Updating Project Zeus source..."
        git -C $InstallDir fetch origin $Branch
        git -C $InstallDir checkout $Branch
        git -C $InstallDir pull --ff-only origin $Branch
    } else {
        if (Test-Path $InstallDir) {
            throw "InstallDir exists but is not a git checkout: $InstallDir"
        }
        Write-Info "Cloning Project Zeus..."
        git clone --branch $Branch $RepoUrlHttps $InstallDir
    }
}

function Install-ZeusPackage {
    Push-Location $InstallDir
    try {
        if ($NoVenv) {
            Write-Info "Installing Zeus package into current Python environment..."
            & $UvCmd pip install -e .
        } else {
            Write-Info "Creating Zeus virtual environment..."
            & $UvCmd venv --python $PythonVersion .venv
            $python = Join-Path $InstallDir ".venv\Scripts\python.exe"
            & $UvCmd pip install --python $python -e .
        }
    } finally {
        Pop-Location
    }
}

function New-ZeusCommandShim {
    $binDir = "$env:LOCALAPPDATA\Microsoft\WindowsApps"
    if (-not (Test-Path $binDir)) {
        $binDir = "$ZeusHome\bin"
        New-Item -ItemType Directory -Force -Path $binDir | Out-Null
        Write-Warn "Add this directory to PATH if needed: $binDir"
    }

    $cmdPath = Join-Path $binDir "zeus.cmd"
    $python = if ($NoVenv) { "python" } else { Join-Path $InstallDir ".venv\Scripts\python.exe" }
    $shim = "@echo off`r`nset ZEUS_HOME=$ZeusHome`r`nset HERMES_HOME=$ZeusHome`r`n`"$python`" -m zeus_cli %*`r`n"
    Set-Content -Path $cmdPath -Value $shim -Encoding ASCII
    Write-Success "Created zeus command shim: $cmdPath"
}

function Initialize-ZeusRuntime {
    $env:ZEUS_HOME = $ZeusHome
    $env:HERMES_HOME = $ZeusHome
    $python = if ($NoVenv) { "python" } else { Join-Path $InstallDir ".venv\Scripts\python.exe" }
    & $python -m zeus_cli --help | Out-Null
    Write-Success "Initialized independent Zeus home: $ZeusHome"
}

Write-Banner
Install-Uv
Install-GitIfNeeded
Install-ZeusSource
Install-ZeusPackage
New-ZeusCommandShim
Initialize-ZeusRuntime

if (-not $SkipSetup) {
    Write-Info "Launching Zeus setup..."
    $env:ZEUS_HOME = $ZeusHome
    $env:HERMES_HOME = $ZeusHome
    zeus setup
}

Write-Success "Zeus is installed. Open a new PowerShell window and run: zeus"
