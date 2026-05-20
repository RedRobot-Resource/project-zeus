# Zeus Windows app shell
# Opens a branded Zeus console, pins the isolated Zeus runtime home, and keeps
# the window open long enough for a Windows user to read first-run guidance.

param(
    [string]$ZeusHome = "$env:LOCALAPPDATA\Zeus",
    [string]$InstallDir = "$env:LOCALAPPDATA\Zeus\project-zeus"
)

$ErrorActionPreference = "Continue"
$Host.UI.RawUI.WindowTitle = "Zeus by Red Robot Resource"
$env:ZEUS_HOME = $ZeusHome
$env:HERMES_HOME = $ZeusHome
$env:HERMES_RUNTIME_BRAND = "Zeus"

$zeusCmd = Join-Path $ZeusHome "bin\zeus.cmd"
$startHere = Join-Path $ZeusHome "ZEUS_START_HERE.md"

Clear-Host
Write-Host ""
Write-Host "============================================================" -ForegroundColor Red
Write-Host "                    Zeus by Red Robot Resource              " -ForegroundColor Red
Write-Host "============================================================" -ForegroundColor Red
Write-Host "Home: $ZeusHome" -ForegroundColor DarkGray
Write-Host ""

if (Test-Path $startHere) {
    Write-Host "Start guide: $startHere" -ForegroundColor Cyan
} else {
    Write-Host "First run guide will be created on the next Zeus launch." -ForegroundColor Yellow
}

Write-Host "Quick commands:" -ForegroundColor Cyan
Write-Host "  zeus setup" -ForegroundColor White
Write-Host "  zeus health" -ForegroundColor White
Write-Host "  zeus gateway install" -ForegroundColor White
Write-Host "  zeus gateway status" -ForegroundColor White
Write-Host ""

if (Test-Path $InstallDir) {
    Set-Location $InstallDir
}

if (Test-Path $zeusCmd) {
    Write-Host "Running Zeus health check..." -ForegroundColor Cyan
    & $zeusCmd health
    Write-Host ""
    Write-Host "If health shows MISSING, run the Zeus repair command from the Start Menu." -ForegroundColor Yellow
    Write-Host ""
    & $zeusCmd
} else {
    Write-Host "Could not find Zeus command shim at $zeusCmd" -ForegroundColor Yellow
    Write-Host "Run the Zeus installer repair command from the Start Menu." -ForegroundColor Yellow
}

Write-Host ""
Read-Host "Zeus session ended. Press Enter to close this window"
