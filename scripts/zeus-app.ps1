# Zeus Windows app shell
# Opens a branded desktop-style launcher instead of dropping directly into a
# command prompt. The console fallback stays available for locked-down Windows
# sessions where WinForms cannot be loaded.

param(
    [string]$ZeusHome = "$env:LOCALAPPDATA\Zeus",
    [string]$InstallDir = "$env:LOCALAPPDATA\Zeus\project-zeus",
    [switch]$ConsoleFallback
)

$ErrorActionPreference = "Continue"
$env:ZEUS_HOME = $ZeusHome
$env:HERMES_HOME = $ZeusHome
$env:HERMES_RUNTIME_BRAND = "Zeus"

$zeusCmd = Join-Path $ZeusHome "bin\zeus.cmd"
$startHere = Join-Path $ZeusHome "ZEUS_START_HERE.md"
$repairCmd = Join-Path $ZeusHome "bin\zeus-repair.cmd"
$updateCmd = Join-Path $ZeusHome "bin\zeus-update.cmd"

function ConvertTo-ZeusCmdArgument {
    param([string]$Value)
    if ($null -eq $Value) {
        return '""'
    }
    return '"' + ($Value -replace '"', '\"') + '"'
}

function Join-ZeusCommandArguments {
    param([string[]]$Values)
    if (-not $Values -or $Values.Count -eq 0) {
        return ""
    }
    return ($Values | ForEach-Object { ConvertTo-ZeusCmdArgument -Value $_ }) -join " "
}

function Invoke-ZeusCommandWindow {
    param(
        [string]$Title,
        [string[]]$Arguments = @(),
        [switch]$KeepOpen
    )

    if (-not (Test-Path $zeusCmd)) {
        [System.Windows.Forms.MessageBox]::Show(
            "Zeus command was not found. Run Zeus Repair from the Start Menu.",
            "Zeus needs repair",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null
        return
    }

    $quotedInstallDir = ConvertTo-ZeusCmdArgument -Value $InstallDir
    $quotedZeusCmd = ConvertTo-ZeusCmdArgument -Value $zeusCmd
    $quotedTitle = ConvertTo-ZeusCmdArgument -Value $Title
    $argumentText = Join-ZeusCommandArguments -Values $Arguments
    $cmdLine = "cd /d $quotedInstallDir && $quotedZeusCmd"
    if ($argumentText) {
        $cmdLine = "$cmdLine $argumentText"
    }
    if ($KeepOpen) {
        $cmdLine = "$cmdLine & echo. & echo Zeus session ended. Press any key to close. & pause >nul"
        Start-Process -FilePath "cmd.exe" -ArgumentList "/k title $quotedTitle && $cmdLine" -WorkingDirectory $InstallDir | Out-Null
    } else {
        Start-Process -FilePath "cmd.exe" -ArgumentList "/c title $quotedTitle && $cmdLine" -WorkingDirectory $InstallDir | Out-Null
    }
}

function Invoke-ZeusExternalScript {
    param([string]$Path)
    if (Test-Path $Path) {
        Start-Process -FilePath $Path -WorkingDirectory $ZeusHome | Out-Null
    } else {
        [System.Windows.Forms.MessageBox]::Show(
            "Could not find: $Path",
            "Zeus",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
    }
}

function Show-ZeusConsoleFallback {
    $Host.UI.RawUI.WindowTitle = "Zeus by Red Robot Resource"
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

    Write-Host ""
    Write-Host "Opening Zeus chat. Use the desktop launcher next time for setup, health, and gateway controls." -ForegroundColor Cyan
    Write-Host ""

    if (Test-Path $InstallDir) {
        Set-Location $InstallDir
    }

    if (Test-Path $zeusCmd) {
        & $zeusCmd health
        Write-Host ""
        & $zeusCmd
    } else {
        Write-Host "Could not find Zeus command shim at $zeusCmd" -ForegroundColor Yellow
        Write-Host "Run the Zeus repair command from the Start Menu." -ForegroundColor Yellow
    }

    Write-Host ""
    Read-Host "Zeus session ended. Press Enter to close this window"
}

if ($ConsoleFallback) {
    Show-ZeusConsoleFallback
    exit
}

try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
} catch {
    Show-ZeusConsoleFallback
    exit
}

[System.Windows.Forms.Application]::EnableVisualStyles()

$form = New-Object System.Windows.Forms.Form
$form.Text = "Zeus by Red Robot Resource"
$form.StartPosition = "CenterScreen"
$form.Size = New-Object System.Drawing.Size(560, 520)
$form.MinimumSize = New-Object System.Drawing.Size(520, 480)
$form.BackColor = [System.Drawing.Color]::FromArgb(18, 24, 32)
$form.ForeColor = [System.Drawing.Color]::White
$form.Font = New-Object System.Drawing.Font("Segoe UI", 10)

$header = New-Object System.Windows.Forms.Label
$header.Text = "Zeus"
$header.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 30, [System.Drawing.FontStyle]::Bold)
$header.ForeColor = [System.Drawing.Color]::FromArgb(255, 74, 74)
$header.AutoSize = $true
$header.Location = New-Object System.Drawing.Point(28, 22)
$form.Controls.Add($header)

$subtitle = New-Object System.Windows.Forms.Label
$subtitle.Text = "Red Robot Resource secure AI workspace"
$subtitle.Font = New-Object System.Drawing.Font("Segoe UI", 11)
$subtitle.ForeColor = [System.Drawing.Color]::FromArgb(206, 214, 224)
$subtitle.AutoSize = $true
$subtitle.Location = New-Object System.Drawing.Point(34, 82)
$form.Controls.Add($subtitle)

$status = New-Object System.Windows.Forms.Label
$status.Text = "Home: $ZeusHome"
$status.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$status.ForeColor = [System.Drawing.Color]::FromArgb(150, 160, 175)
$status.AutoSize = $true
$status.Location = New-Object System.Drawing.Point(34, 112)
$form.Controls.Add($status)

$panel = New-Object System.Windows.Forms.Panel
$panel.Location = New-Object System.Drawing.Point(30, 150)
$panel.Size = New-Object System.Drawing.Size(485, 245)
$panel.BackColor = [System.Drawing.Color]::FromArgb(28, 36, 48)
$form.Controls.Add($panel)

function New-ZeusButton {
    param(
        [string]$Text,
        [int]$X,
        [int]$Y,
        [scriptblock]$OnClick,
        [switch]$Primary
    )

    $button = New-Object System.Windows.Forms.Button
    $button.Text = $Text
    $button.Size = New-Object System.Drawing.Size(210, 48)
    $button.Location = New-Object System.Drawing.Point($X, $Y)
    $button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $button.FlatAppearance.BorderSize = 0
    $button.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 10, [System.Drawing.FontStyle]::Bold)
    $button.Cursor = [System.Windows.Forms.Cursors]::Hand
    if ($Primary) {
        $button.BackColor = [System.Drawing.Color]::FromArgb(255, 74, 74)
        $button.ForeColor = [System.Drawing.Color]::White
    } else {
        $button.BackColor = [System.Drawing.Color]::FromArgb(50, 62, 78)
        $button.ForeColor = [System.Drawing.Color]::FromArgb(235, 240, 245)
    }
    $button.Add_Click($OnClick)
    $panel.Controls.Add($button)
}

New-ZeusButton -Text "Open Zeus Chat" -X 22 -Y 24 -Primary -OnClick { Invoke-ZeusCommandWindow -Title "Zeus Chat" -KeepOpen }
New-ZeusButton -Text "Guided Setup" -X 252 -Y 24 -OnClick { Invoke-ZeusCommandWindow -Title "Zeus Setup" -Arguments "setup" -KeepOpen }
New-ZeusButton -Text "Health Check" -X 22 -Y 92 -OnClick { Invoke-ZeusCommandWindow -Title "Zeus Health" -Arguments "health" -KeepOpen }
New-ZeusButton -Text "Settings" -X 252 -Y 92 -OnClick { Invoke-ZeusCommandWindow -Title "Zeus Settings" -Arguments "config" -KeepOpen }
New-ZeusButton -Text "Gateway Status" -X 22 -Y 160 -OnClick { Invoke-ZeusCommandWindow -Title "Zeus Gateway" -Arguments "gateway", "status" -KeepOpen } # zeus gateway status
New-ZeusButton -Text "Repair / Update" -X 252 -Y 160 -OnClick {
    if (Test-Path $repairCmd) {
        Invoke-ZeusExternalScript -Path $repairCmd
    } elseif (Test-Path $updateCmd) {
        Invoke-ZeusExternalScript -Path $updateCmd
    } else {
        Invoke-ZeusCommandWindow -Title "Zeus Health" -Arguments "health" -KeepOpen
    }
}

$guide = New-Object System.Windows.Forms.Button
$guide.Text = "Open first-run guide"
$guide.Size = New-Object System.Drawing.Size(210, 32)
$guide.Location = New-Object System.Drawing.Point(34, 415)
$guide.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$guide.FlatAppearance.BorderSize = 1
$guide.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(95, 110, 130)
$guide.BackColor = [System.Drawing.Color]::FromArgb(18, 24, 32)
$guide.ForeColor = [System.Drawing.Color]::FromArgb(230, 235, 240)
$guide.Add_Click({
    if (Test-Path $startHere) {
        Start-Process -FilePath $startHere | Out-Null
    } else {
        Invoke-ZeusCommandWindow -Title "Zeus Health" -Arguments "health" -KeepOpen
    }
})
$form.Controls.Add($guide)

$close = New-Object System.Windows.Forms.Button
$close.Text = "Close"
$close.Size = New-Object System.Drawing.Size(110, 32)
$close.Location = New-Object System.Drawing.Point(405, 415)
$close.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$close.FlatAppearance.BorderSize = 0
$close.BackColor = [System.Drawing.Color]::FromArgb(50, 62, 78)
$close.ForeColor = [System.Drawing.Color]::FromArgb(230, 235, 240)
$close.Add_Click({ $form.Close() })
$form.Controls.Add($close)

[System.Windows.Forms.Application]::Run($form)
