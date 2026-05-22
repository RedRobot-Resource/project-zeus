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
#   .\install-zeus.ps1 -Update
#   .\install-zeus.ps1 -Repair
#   .\install-zeus.ps1 -Uninstall
# ============================================================================

param(
    [switch]$NoVenv,
    [switch]$SkipSetup,
    [switch]$Update,
    [switch]$Repair,
    [switch]$Uninstall,
    [switch]$PreserveUserData = $true,
    [string]$Branch = "main",
    [string]$ZeusHome = "$env:LOCALAPPDATA\Zeus",
    [string]$InstallDir = "$env:LOCALAPPDATA\Zeus\project-zeus"
)

$ErrorActionPreference = "Stop"

$RepoUrlHttps = "https://github.com/RedRobot-Resource/project-zeus.git"
$PythonVersion = "3.11"
$ZeusInstallLogDir = Join-Path $ZeusHome "logs"
$ZeusInstallLog = Join-Path $ZeusInstallLogDir ("install-{0}.log" -f (Get-Date -Format "yyyyMMdd-HHmmss"))
$ZeusBinDir = Join-Path $ZeusHome "bin"
$ZeusShortcutName = "Zeus.lnk"
$ZeusConsoleShortcutName = "Zeus Console.lnk"
$ZeusAppLauncherName = "zeus-app.cmd"
$ZeusUninstallName = "Uninstall Zeus.cmd"
$ZeusRepairName = "zeus-repair.cmd"
$ZeusUpdateName = "zeus-update.cmd"
$ZeusGatewayInstallName = "zeus-gateway-install.cmd"
$ZeusGatewayStartName = "zeus-gateway-start.cmd"
$ZeusGatewayStopName = "zeus-gateway-stop.cmd"
$ZeusGatewayStatusName = "zeus-gateway-status.cmd"
$UserStatePaths = @("auth.json", "config.yaml", ".env", "sessions", "memories", "state.db", "logs", "workspace", "home")

function Write-Banner {
    Write-Host ""
    Write-Host "===========================================================" -ForegroundColor Red
    Write-Host "|                  Zeus Installer                            |" -ForegroundColor Red
    Write-Host "===========================================================" -ForegroundColor Red
    Write-Host "|        A Red Robot Resource Windows AI client.          |" -ForegroundColor Red
    Write-Host "|        Runs independently from Hermes Agent.            |" -ForegroundColor Red
    Write-Host "===========================================================" -ForegroundColor Red
    Write-Host ""
}

function Write-Info { param([string]$Message) Write-Host "INFO: $Message" -ForegroundColor Cyan }
function Write-Success { param([string]$Message) Write-Host "OK: $Message" -ForegroundColor Green }
function Write-Warn { param([string]$Message) Write-Host "WARN: $Message" -ForegroundColor Yellow }
function Write-Err { param([string]$Message) Write-Host "ERR: $Message" -ForegroundColor Red }

function Start-ZeusInstallLog {
    New-Item -ItemType Directory -Force -Path $ZeusInstallLogDir | Out-Null
    try {
        Start-Transcript -Path $ZeusInstallLog -Append | Out-Null
        Write-Info "Install log: $ZeusInstallLog"
    } catch {
        Write-Warn "Could not start install transcript: $_"
    }
}

function Stop-ZeusInstallLog {
    try { Stop-Transcript | Out-Null } catch { }
}

function Get-ZeusPython {
    if ($NoVenv) { return "python" }
    return Join-Path $InstallDir ".venv\Scripts\python.exe"
}

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
            $python = Get-ZeusPython
            & $UvCmd pip install --python $python -e .
        }
    } finally {
        Pop-Location
    }
}

function New-ZeusCommandShim {
    New-Item -ItemType Directory -Force -Path $ZeusBinDir | Out-Null
    $cmdPath = Join-Path $ZeusBinDir "zeus.cmd"
    $python = Get-ZeusPython
    $shim = "@echo off`r`nset ZEUS_HOME=$ZeusHome`r`nset HERMES_HOME=$ZeusHome`r`nset HERMES_RUNTIME_BRAND=Zeus`r`n`"$python`" -m zeus_cli %*`r`n"
    Set-Content -Path $cmdPath -Value $shim -Encoding ASCII
    Write-Success "Created zeus command shim: $cmdPath"

    $windowsApps = "$env:LOCALAPPDATA\Microsoft\WindowsApps"
    if (Test-Path $windowsApps) {
        $publicCmd = Join-Path $windowsApps "zeus.cmd"
        Set-Content -Path $publicCmd -Value $shim -Encoding ASCII
        Write-Success "Created PATH command shim: $publicCmd"
    } else {
        Write-Warn "Add this directory to PATH if needed: $ZeusBinDir"
    }
}

function New-ZeusAppShell {
    New-Item -ItemType Directory -Force -Path $ZeusBinDir | Out-Null
    $launcherPath = Join-Path $ZeusBinDir $ZeusAppLauncherName
    $appShell = Join-Path $InstallDir "scripts\zeus-app.ps1"
    $launcher = "@echo off`r`nset ZEUS_HOME=$ZeusHome`r`nset HERMES_HOME=$ZeusHome`r`nset HERMES_RUNTIME_BRAND=Zeus`r`npowershell -ExecutionPolicy Bypass -File `"$appShell`" -ZeusHome `"$ZeusHome`" -InstallDir `"$InstallDir`"`r`n"
    Set-Content -Path $launcherPath -Value $launcher -Encoding ASCII
    Write-Success "Created Zeus app shell: $launcherPath"
}

function New-ZeusDesktopShortcut {
    $desktop = [Environment]::GetFolderPath("Desktop")
    if (-not $desktop) { return }
    $shortcutPath = Join-Path $desktop $ZeusShortcutName
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = Join-Path $ZeusBinDir $ZeusAppLauncherName
    $shortcut.WorkingDirectory = $ZeusHome
    $shortcut.Description = "Launch Zeus by Red Robot Resource"
    $shortcut.Save()
    Write-Success "Created Desktop shortcut: $shortcutPath"
}

function New-ZeusStartMenuShortcut {
    $programs = [Environment]::GetFolderPath("Programs")
    if (-not $programs) { return }
    $folder = Join-Path $programs "Zeus"
    New-Item -ItemType Directory -Force -Path $folder | Out-Null

    $shortcutPath = Join-Path $folder $ZeusShortcutName
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = Join-Path $ZeusBinDir $ZeusAppLauncherName
    $shortcut.WorkingDirectory = $ZeusHome
    $shortcut.Description = "Launch Zeus by Red Robot Resource"
    $shortcut.Save()

    $consoleShortcutPath = Join-Path $folder $ZeusConsoleShortcutName
    $consoleShortcut = $shell.CreateShortcut($consoleShortcutPath)
    $consoleShortcut.TargetPath = Join-Path $ZeusBinDir "zeus.cmd"
    $consoleShortcut.WorkingDirectory = $ZeusHome
    $consoleShortcut.Description = "Open Zeus command console by Red Robot Resource"
    $consoleShortcut.Save()

    Set-Content -Path (Join-Path $folder $ZeusUninstallName) -Value "@echo off`r`npowershell -ExecutionPolicy Bypass -File `"$InstallDir\scripts\install-zeus.ps1`" -Uninstall`r`n" -Encoding ASCII
    Set-Content -Path (Join-Path $folder $ZeusRepairName) -Value "@echo off`r`npowershell -ExecutionPolicy Bypass -File `"$InstallDir\scripts\install-zeus.ps1`" -Repair -SkipSetup`r`n" -Encoding ASCII
    Set-Content -Path (Join-Path $folder $ZeusUpdateName) -Value "@echo off`r`npowershell -ExecutionPolicy Bypass -File `"$InstallDir\scripts\install-zeus.ps1`" -Update -SkipSetup`r`n" -Encoding ASCII
    Write-Success "Created Start Menu shortcuts: $folder"
}

function Install-ZeusUninstaller {
    New-Item -ItemType Directory -Force -Path $ZeusBinDir | Out-Null
    Set-Content -Path (Join-Path $ZeusBinDir $ZeusUninstallName) -Value "@echo off`r`npowershell -ExecutionPolicy Bypass -File `"$InstallDir\scripts\install-zeus.ps1`" -Uninstall`r`n" -Encoding ASCII
    Set-Content -Path (Join-Path $ZeusBinDir $ZeusRepairName) -Value "@echo off`r`npowershell -ExecutionPolicy Bypass -File `"$InstallDir\scripts\install-zeus.ps1`" -Repair -SkipSetup`r`n" -Encoding ASCII
    Set-Content -Path (Join-Path $ZeusBinDir $ZeusUpdateName) -Value "@echo off`r`npowershell -ExecutionPolicy Bypass -File `"$InstallDir\scripts\install-zeus.ps1`" -Update -SkipSetup`r`n" -Encoding ASCII
    Write-Success "Created repair, update, and uninstall commands in $ZeusBinDir"
}


function Install-ZeusGatewayServiceCommands {
    New-Item -ItemType Directory -Force -Path $ZeusBinDir | Out-Null
    $prefix = "@echo off`r`nset ZEUS_HOME=$ZeusHome`r`nset HERMES_HOME=$ZeusHome`r`nset HERMES_RUNTIME_BRAND=Zeus`r`n"
    Set-Content -Path (Join-Path $ZeusBinDir $ZeusGatewayInstallName) -Value ($prefix + "zeus gateway install`r`n") -Encoding ASCII
    Set-Content -Path (Join-Path $ZeusBinDir $ZeusGatewayStartName) -Value ($prefix + "zeus gateway start`r`n") -Encoding ASCII
    Set-Content -Path (Join-Path $ZeusBinDir $ZeusGatewayStopName) -Value ($prefix + "zeus gateway stop`r`n") -Encoding ASCII
    Set-Content -Path (Join-Path $ZeusBinDir $ZeusGatewayStatusName) -Value ($prefix + "zeus gateway status`r`n") -Encoding ASCII
    Write-Success "Created Zeus gateway service controls in $ZeusBinDir"
}

function Initialize-ZeusRuntime {
    $env:ZEUS_HOME = $ZeusHome
    $env:HERMES_HOME = $ZeusHome
    $python = Get-ZeusPython
    & $python -m zeus_cli --help | Out-Null
    Write-Success "Initialized independent Zeus home: $ZeusHome"
}

function Update-Zeus {
    Write-Info "Updating Zeus client..."
    Install-Uv
    Install-GitIfNeeded
    Install-ZeusSource
    Install-ZeusPackage
    New-ZeusCommandShim
    New-ZeusAppShell
    New-ZeusDesktopShortcut
    New-ZeusStartMenuShortcut
    Install-ZeusUninstaller
    Install-ZeusGatewayServiceCommands
    Initialize-ZeusRuntime
    Write-Success "Zeus update complete."
}

function Repair-Zeus {
    Write-Info "Repairing Zeus while preserving user data: $PreserveUserData"
    foreach ($statePath in $UserStatePaths) {
        $full = Join-Path $ZeusHome $statePath
        if (Test-Path $full) { Write-Info "Preserving user state: $statePath" }
    }
    Install-Uv
    Install-GitIfNeeded
    Install-ZeusSource
    Install-ZeusPackage
    New-ZeusCommandShim
    New-ZeusAppShell
    New-ZeusDesktopShortcut
    New-ZeusStartMenuShortcut
    Install-ZeusUninstaller
    Install-ZeusGatewayServiceCommands
    Initialize-ZeusRuntime
    Write-Success "Zeus repair complete."
}

function Uninstall-Zeus {
    Write-Warn "Uninstalling Zeus application files. PreserveUserData=$PreserveUserData"
    $desktop = [Environment]::GetFolderPath("Desktop")
    if ($desktop) { Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $desktop $ZeusShortcutName) }

    $programs = [Environment]::GetFolderPath("Programs")
    if ($programs) { Remove-Item -Recurse -Force -ErrorAction SilentlyContinue (Join-Path $programs "Zeus") }

    Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path "$env:LOCALAPPDATA\Microsoft\WindowsApps" "zeus.cmd")
    Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $ZeusBinDir "zeus.cmd")
    Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $ZeusBinDir $ZeusAppLauncherName)
    Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $ZeusBinDir $ZeusUninstallName)
    Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $ZeusBinDir $ZeusRepairName)
    Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $ZeusBinDir $ZeusUpdateName)
    Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $ZeusBinDir $ZeusGatewayInstallName)
    Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $ZeusBinDir $ZeusGatewayStartName)
    Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $ZeusBinDir $ZeusGatewayStopName)
    Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $ZeusBinDir $ZeusGatewayStatusName)

    if (Test-Path $InstallDir) {
        Remove-Item -Recurse -Force $InstallDir
    }

    if ($PreserveUserData) {
        Write-Success "Removed Zeus app files. User data remains at $ZeusHome"
    } else {
        foreach ($statePath in $UserStatePaths) {
            $full = Join-Path $ZeusHome $statePath
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $full
        }
        Write-Success "Removed Zeus app files and selected user state files from $ZeusHome"
    }
}

function Install-Zeus {
    Install-Uv
    Install-GitIfNeeded
    Install-ZeusSource
    Install-ZeusPackage
    New-ZeusCommandShim
    New-ZeusAppShell
    New-ZeusDesktopShortcut
    New-ZeusStartMenuShortcut
    Install-ZeusUninstaller
    Install-ZeusGatewayServiceCommands
    Initialize-ZeusRuntime

    if (-not $SkipSetup) {
        Write-Info "Launching Zeus setup..."
        $env:ZEUS_HOME = $ZeusHome
        $env:HERMES_HOME = $ZeusHome
        zeus setup
    }

    Write-Success "Zeus is installed. Open a new PowerShell window and run: zeus"
}

try {
    Write-Banner
    Start-ZeusInstallLog
    if ($Uninstall) {
        Uninstall-Zeus
    } elseif ($Repair) {
        Repair-Zeus
    } elseif ($Update) {
        Update-Zeus
    } else {
        Install-Zeus
    }
} finally {
    Stop-ZeusInstallLog
}
