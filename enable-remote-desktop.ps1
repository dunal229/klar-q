<#
    enable-remote-desktop.ps1
    Enables Windows Remote Desktop (RDP) so you can screen-share into this
    PC from your Mac over Tailscale.

    - Detects the Windows edition. RDP host requires Pro/Enterprise/Education;
      Windows Home cannot host RDP (use VNC instead - see notes printed at end).
    - Turns on Remote Desktop, opens the firewall for it, and ensures the
      service is running.
    - Prints the Tailscale IP and the exact Mac connection details.

    Needs Administrator; self-elevates.

    Run:
      Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
      .\enable-remote-desktop.ps1
#>

$ErrorActionPreference = 'Stop'

# ---- self-elevate ---------------------------------------------------------
$elevated = ([Security.Principal.WindowsPrincipal] `
             [Security.Principal.WindowsIdentity]::GetCurrent()
            ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $elevated) {
    Write-Host 'Elevating to Administrator...' -ForegroundColor Cyan
    $self = $PSCommandPath
    if ([string]::IsNullOrWhiteSpace($self) -or -not (Test-Path $self)) {
        $self = Join-Path $env:TEMP 'enable-remote-desktop.ps1'
        Invoke-WebRequest -Uri 'https://github.com/dunal229/klar-q/raw/claude/github-windows-setup-u13thr/enable-remote-desktop.ps1' -OutFile $self
    }
    Start-Process powershell -Verb RunAs -ArgumentList @(
        '-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$self`""
    )
    return
}

$report = [System.Collections.Generic.List[string]]::new()
function Ok($m)   { Write-Host "[ OK ] $m" -ForegroundColor Green; $report.Add("OK   : $m") }
function Info($m) { Write-Host "[INFO] $m"  -ForegroundColor Cyan }
function Fail($m) { Write-Host "[FAIL] $m" -ForegroundColor Red;   $report.Add("FAIL : $m") }

try {
    $edition = (Get-CimInstance Win32_OperatingSystem).Caption
    Ok "Windows edition: $edition"

    if ($edition -match 'Home') {
        Fail 'This is Windows Home - it cannot host Remote Desktop (RDP).'
        Info 'Use VNC instead: install a VNC server (e.g. TightVNC or UltraVNC),'
        Info 'then on the Mac open Finder > Go > Connect to Server > vnc://<tailscale-ip>'
        Info 'Tell me if you want a VNC setup script and I will build one.'
    } else {
        # Enable Remote Desktop
        Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' `
            -Name 'fDenyTSConnections' -Value 0
        Ok 'Remote Desktop enabled (fDenyTSConnections = 0).'

        # Keep Network Level Authentication on (more secure).
        Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' `
            -Name 'UserAuthentication' -Value 1
        Ok 'Network Level Authentication enabled.'

        # Open the firewall for RDP.
        Enable-NetFirewallRule -DisplayGroup 'Remote Desktop'
        Ok 'Firewall opened for Remote Desktop.'

        # Ensure the RDP service is running + automatic.
        Set-Service -Name TermService -StartupType Automatic
        if ((Get-Service TermService).Status -ne 'Running') { Start-Service TermService }
        Ok ("Remote Desktop service: " + (Get-Service TermService).Status)
    }

    # ---- connection details ----------------------------------------------
    $tsExe = (Get-Command tailscale -ErrorAction SilentlyContinue).Source
    if (-not $tsExe) { $tsExe = Join-Path $env:ProgramFiles 'Tailscale\tailscale.exe' }
    $ip = if (Test-Path $tsExe) { (& $tsExe ip -4) -join ', ' } else { '(tailscale not found)' }

    $report.Add("EDITION   : $edition")
    $report.Add("TAILSCALE : $ip")
    $report.Add("RDP_USER  : $env:USERNAME")
}
catch {
    Fail $_.Exception.Message
}
finally {
    Write-Host ''
    Write-Host '===== REPORT =====' -ForegroundColor Yellow
    $report | ForEach-Object { Write-Host $_ }
    Write-Host '=================='
    Write-Host 'Press Enter to close...'
    [void](Read-Host)
}
