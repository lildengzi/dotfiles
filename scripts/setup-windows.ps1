param(
    [switch]$SkipSoftware,
    [switch]$Help
)

if ($Help) {
    Write-Host @"
Usage: .\setup-windows.ps1 [options]

Deploys Windows dotfiles from the windows/ directory to the correct paths.
Software installation failures will not stop config file deployment.

Options:
  -SkipSoftware   Copy config files only, skip software installation
  -Help           Show this help message
"@
    return
}

$ErrorActionPreference = "Continue"

$DotfilesRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$WindowsConfigDir = Join-Path $DotfilesRoot "windows"

$UserProfile = $env:USERPROFILE

function Copy-Config {
    param(
        [string]$Source,
        [string]$Dest
    )
    if (Test-Path $Source) {
        $parent = Split-Path $Dest -Parent
        if (-not (Test-Path $parent)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }
        Copy-Item -Path $Source -Destination $Dest -Force
        Write-Host "  [OK] $Source -> $Dest" -ForegroundColor Green
    } else {
        Write-Host "  [SKIP] Source not found: $Source" -ForegroundColor Yellow
    }
}

function Install-Software {
    Write-Host "`n=== Installing software via scoop ===" -ForegroundColor Cyan
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        scoop install git neovim wezterm nushell 2>&1 | ForEach-Object { Write-Host "  scoop: $_" }
    } else {
        Write-Host "  scoop not found, skipping" -ForegroundColor Yellow
    }

    Write-Host "`n=== Installing software via winget ===" -ForegroundColor Cyan
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install --id Microsoft.WindowsTerminal -e --accept-source-agreements 2>&1 | ForEach-Object { Write-Host "  winget: $_" }
        winget install --id Microsoft.PowerShell -e --accept-source-agreements 2>&1 | ForEach-Object { Write-Host "  winget: $_" }
    } else {
        Write-Host "  winget not found, skipping" -ForegroundColor Yellow
    }
}

Write-Host "=== Windows Dotfiles Setup ===" -ForegroundColor Cyan
Write-Host "Dotfiles root: $DotfilesRoot`n"

# --- Starship ---
Write-Host "--- Starship ---" -ForegroundColor Yellow
Copy-Config (Join-Path $WindowsConfigDir "starship\starship.toml") (Join-Path $UserProfile ".config\starship\starship.toml")
Copy-Config (Join-Path $WindowsConfigDir "starship\init.nu") (Join-Path $UserProfile ".config\starship\init.nu")

# --- Mintty (default terminal) ---
Write-Host "`n--- Mintty ---" -ForegroundColor Yellow
Copy-Config (Join-Path $WindowsConfigDir "mintty\minttyrc") (Join-Path $UserProfile ".config\mintty\minttyrc")

# --- WezTerm (optional terminal, kept as fallback) ---
Write-Host "`n--- WezTerm (optional) ---" -ForegroundColor Yellow
Copy-Config (Join-Path $WindowsConfigDir "wezterm\wezterm.lua") (Join-Path $UserProfile ".config\wezterm\wezterm.lua")

# --- Nushell ---
Write-Host "`n--- Nushell ---" -ForegroundColor Yellow
Copy-Config (Join-Path $WindowsConfigDir "nushell\config.nu") (Join-Path $UserProfile ".config\nushell\config.nu")

# --- Komorebi ---
Write-Host "`n--- Komorebi ---" -ForegroundColor Yellow
Copy-Config (Join-Path $WindowsConfigDir "komorebi\komorebi.json") (Join-Path $UserProfile ".config\komorebi\komorebi.json")
Copy-Config (Join-Path $WindowsConfigDir "komorebi\komorebi-schema.json") (Join-Path $UserProfile "komorebi-schema.json")
Copy-Config (Join-Path $WindowsConfigDir "komorebi\komorebi.bar.json") (Join-Path $UserProfile ".config\komorebi\komorebi.bar.json")

# --- AutoHotKey (komorebi hotkeys) ---
Write-Host "`n--- AutoHotKey ---" -ForegroundColor Yellow
Copy-Config (Join-Path $WindowsConfigDir "autohotkey\komorebi.ahk") (Join-Path $UserProfile ".config\komorebi\komorebi.ahk")

# --- Scoop / Winget manifests (backup only, no auto-import) ---
Write-Host "`n--- Package Manifests (backup only) ---" -ForegroundColor Yellow
Copy-Config (Join-Path $WindowsConfigDir "scoop\export.json") (Join-Path $UserProfile "scoop-export.json")
Copy-Config (Join-Path $WindowsConfigDir "winget\export.yaml") (Join-Path $UserProfile "winget-export.yaml")

Write-Host "`n=== Manifest Import Instructions ===" -ForegroundColor Cyan
Write-Host @"
To restore your package list from the backups:

  Scoop:
    scoop import $UserProfile\scoop-export.json

  Winget:
    winget import $UserProfile\winget-export.yaml

Or manually install each package listed in the export files.
"@

# --- Scheduled tasks (komorebi WM + AHK hotkeys auto-start) ---
Write-Host "`n--- Scheduled Tasks ---" -ForegroundColor Yellow
function Register-LoginTask {
    param([string]$TaskName, [string]$Execute, [string]$Argument)
    $action = New-ScheduledTaskAction -Execute $Execute -Argument $Argument
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERNAME"
    $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
    Write-Host "  [OK] Registered task: $TaskName" -ForegroundColor Green
}

$komorebicExe = "C:\Program Files\komorebi\bin\komorebic.exe"
$ahkExe = "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe"

if (Test-Path $komorebicExe) {
    Register-LoginTask -TaskName "Komorebi" -Execute $komorebicExe -Argument "start --config $UserProfile\.config\komorebi\komorebi.json"
} else {
    Write-Host "  [SKIP] komorebic.exe not found" -ForegroundColor Yellow
}
if (Test-Path $ahkExe) {
    Register-LoginTask -TaskName "Komorebi-AHK" -Execute $ahkExe -Argument "$UserProfile\.config\komorebi\komorebi.ahk"
} else {
    Write-Host "  [SKIP] AutoHotkey64.exe not found" -ForegroundColor Yellow
}

# --- Software Installation ---
if (-not $SkipSoftware) {
    Write-Host "`n=== Installing software ===" -ForegroundColor Cyan
    try {
        Install-Software
    } catch {
        Write-Host "  Software installation failed, but config files were already deployed." -ForegroundColor Yellow
    }
} else {
    Write-Host "`n=== Skipping software installation (-SkipSoftware) ===" -ForegroundColor Yellow
}

Write-Host "`n=== Setup Complete ===" -ForegroundColor Green
Write-Host "Config files have been deployed to the correct Windows paths."
Write-Host "Restart your terminal or reload your shell to apply changes."