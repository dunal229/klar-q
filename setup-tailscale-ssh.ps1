<#
    setup-tailscale-ssh.ps1
    Installs Tailscale, brings it up (browser login), enables the Windows
    OpenSSH Server feature, starts it, and prints this machine's Tailscale IP.

    Requires Administrator. The script self-elevates if you didn't start it
    from an elevated shell.

    During "tailscale up" a browser opens for login — sign in as dunal229@.

    Run:
      Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
      .\setup-tailscale-ssh.ps1
#>

$ErrorActionPreference = 'Stop'

# ---- self-elevate to Administrator ----------------------------------------
$admin = ([Security.Principal.WindowsPrincipal] `
          [Security.Principal.WindowsIdentity]::GetCurrent()
         ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) {
    Write-Host 'Elevating to Administrator...' -ForegroundColor Cyan
    # When launched via "irm <url> | iex" there is no file on disk, so
    # $PSCommandPath is empty and -File would target nothing. In that case
    # save a copy to a temp file and relaunch the elevated shell against it.
    $self = $PSCommandPath
    if ([string]::IsNullOrWhiteSpace($self) -or -not (Test-Path $self)) {
        $self = Join-Path $env:TEMP 'setup-tailscale-ssh.ps1'
        $url  = 'https://github.com/dunal229/klar-q/raw/claude/github-windows-setup-u13thr/setup-tailscale-ssh.ps1'
        Invoke-WebRequest -Uri $url -OutFile $self
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

function Find-Tailscale {
    $cmd = Get-Command tailscale -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $p = Join-Path $env:ProgramFiles 'Tailscale\tailscale.exe'
    if (Test-Path $p) { return $p }
    return $null
}

try {
    # ---- 1. Install Tailscale --------------------------------------------
    if (Find-Tailscale) {
        Ok 'Tailscale already installed.'
    } else {
        Info 'Installing Tailscale...'
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            winget install --id Tailscale.Tailscale -e --source winget `
                --accept-package-agreements --accept-source-agreements
        } else {
            # Fallback: download and run the official MSI silently.
            $msi = Join-Path $env:TEMP 'tailscale-setup.msi'
            Info 'winget not found; downloading MSI from tailscale.com...'
            Invoke-WebRequest -Uri 'https://pkgs.tailscale.com/stable/tailscale-setup-latest.msi' -OutFile $msi
            Start-Process msiexec.exe -ArgumentList "/i `"$msi`" /quiet /norestart" -Wait
        }
        if (Find-Tailscale) { Ok 'Tailscale installed.' }
        else { throw 'Tailscale install did not produce tailscale.exe. Install manually from https://tailscale.com/download/windows and re-run.' }
    }

    $ts = Find-Tailscale

    # ---- 2. Bring Tailscale up (browser login) ---------------------------
    Info 'Running "tailscale up" - a browser will open. Sign in as dunal229@.'
    & $ts up
    if ($LASTEXITCODE -ne 0) { throw 'tailscale up failed (login not completed?).' }
    Ok 'Tailscale is up.'

    # ---- 3. Enable OpenSSH Server feature --------------------------------
    $cap = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*'
    if ($cap.State -eq 'Installed') {
        Ok 'OpenSSH Server feature already installed.'
    } else {
        Info 'Installing OpenSSH Server feature...'
        Add-WindowsCapability -Online -Name $cap.Name | Out-Null
        Ok 'OpenSSH Server feature installed.'
    }

    # ---- 4. Start + auto-start sshd ---------------------------------------
    Set-Service -Name sshd -StartupType Automatic
    Start-Service sshd
    Ok ("sshd service: " + (Get-Service sshd).Status)

    # Ensure firewall allows inbound SSH (port 22).
    if (-not (Get-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' `
            -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 | Out-Null
        Ok 'Added firewall rule for inbound SSH (TCP 22).'
    } else {
        Ok 'Firewall rule for inbound SSH already present.'
    }

    # ---- 5. Report Tailscale IP ------------------------------------------
    $ip = (& $ts ip -4) -join ', '
    Ok "Tailscale IPv4: $ip"
    $report.Add("TAILSCALE_IP : $ip")
    Write-Host ''
    Write-Host "This machine's Tailscale IP: $ip" -ForegroundColor Yellow
    Write-Host "Connect from another tailnet device with:  ssh $env:USERNAME@$ip" -ForegroundColor Yellow
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
