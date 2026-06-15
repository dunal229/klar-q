<#
    authorize-ssh-key.ps1
    Authorizes SSH public-key login to this Windows PC for a Mac client.

    - Reports your Windows username and whether that account is a local
      Administrator.
    - Admin accounts: writes the key to
        C:\ProgramData\ssh\administrators_authorized_keys
      (Windows OpenSSH ignores the per-user file for admins), with
      inheritance disabled and ONLY Administrators:F + SYSTEM:F.
    - Non-admin accounts: writes to
        C:\Users\<you>\.ssh\authorized_keys  (owner-only access)
    - Ensures sshd is Running and set to Automatic startup.

    Needs Administrator (service control + ProgramData). The script
    self-elevates; the admin check is computed from YOUR account before
    elevation and passed through, so it stays accurate.

    Run:
      Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
      .\authorize-ssh-key.ps1
#>

param(
    [string]$ForUser = '',
    [string]$ForIsAdmin = ''
)

$ErrorActionPreference = 'Stop'

$PubKey = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMuk+4JXrnwvp8Co206Wzla2inxHyzIvHTb2f4EeTolR dunal229@gmail.com'

$report = [System.Collections.Generic.List[string]]::new()
function Ok($m)   { Write-Host "[ OK ] $m" -ForegroundColor Green; $report.Add("OK   : $m") }
function Info($m) { Write-Host "[INFO] $m"  -ForegroundColor Cyan }
function Fail($m) { Write-Host "[FAIL] $m" -ForegroundColor Red;   $report.Add("FAIL : $m") }

# ---- Determine username + admin membership of the REAL account ------------
if ($ForUser) {
    $user    = $ForUser
    $isAdmin = [bool]::Parse($ForIsAdmin)
} else {
    $user    = $env:USERNAME
    $isAdmin = $false
    try {
        $members = Get-LocalGroupMember -Group 'Administrators' -ErrorAction Stop
        $isAdmin = [bool]($members | Where-Object { $_.Name -like "*\$user" })
    } catch {
        # Fallback for AzureAD/odd setups: parse net localgroup output.
        $out = net localgroup Administrators 2>$null
        $isAdmin = [bool]($out | Where-Object { $_ -match ("\\?" + [regex]::Escape($user) + '\s*$') })
    }
}

Write-Host ("Windows username : {0}" -f $user)         -ForegroundColor Yellow
Write-Host ("Is Administrator : {0}" -f $isAdmin)       -ForegroundColor Yellow

# ---- Self-elevate (pass computed identity through) ------------------------
$elevated = ([Security.Principal.WindowsPrincipal] `
             [Security.Principal.WindowsIdentity]::GetCurrent()
            ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $elevated) {
    Info 'Elevating to Administrator...'
    $self = $PSCommandPath
    if ([string]::IsNullOrWhiteSpace($self) -or -not (Test-Path $self)) {
        $self = Join-Path $env:TEMP 'authorize-ssh-key.ps1'
        Invoke-WebRequest -Uri 'https://github.com/dunal229/klar-q/raw/claude/github-windows-setup-u13thr/authorize-ssh-key.ps1' -OutFile $self
    }
    Start-Process powershell -Verb RunAs -ArgumentList @(
        '-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$self`"",
        '-ForUser',$user,'-ForIsAdmin',"$isAdmin"
    )
    return
}

try {
    # ---- Pick the correct authorized_keys file ---------------------------
    if ($isAdmin) {
        $dir  = Join-Path $env:ProgramData 'ssh'
        $file = Join-Path $dir 'administrators_authorized_keys'
    } else {
        $dir  = Join-Path "C:\Users\$user" '.ssh'
        $file = Join-Path $dir 'authorized_keys'
    }
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Info "Created $dir"
    }

    # ---- Append the key (idempotent) -------------------------------------
    $existing = if (Test-Path $file) { Get-Content $file -Raw -ErrorAction SilentlyContinue } else { '' }
    if ($existing -and $existing.Contains($PubKey)) {
        Ok "Key already present in $file (not duplicated)."
    } else {
        # ASCII, no BOM - OpenSSH rejects BOM/UTF-16 in these files.
        if ($existing -and -not $existing.EndsWith("`n")) { Add-Content -Path $file -Value '' -Encoding ascii }
        Add-Content -Path $file -Value $PubKey -Encoding ascii
        Ok "Appended key to $file"
    }

    # ---- Lock down permissions -------------------------------------------
    # SIDs: S-1-5-32-544 = Administrators, S-1-5-18 = SYSTEM (locale-proof).
    icacls $file /inheritance:r | Out-Null
    if ($isAdmin) {
        icacls $file /grant '*S-1-5-32-544:F' | Out-Null
        icacls $file /grant '*S-1-5-18:F'     | Out-Null
        Ok "Permissions: inheritance disabled; Administrators:F + SYSTEM:F only."
    } else {
        icacls $file /grant "${user}:F"   | Out-Null
        icacls $file /grant '*S-1-5-18:F' | Out-Null
        Ok "Permissions: inheritance disabled; ${user}:F + SYSTEM:F (owner-only)."
    }

    # ---- sshd: Automatic + Running ---------------------------------------
    Set-Service -Name sshd -StartupType Automatic
    if ((Get-Service sshd).Status -ne 'Running') { Start-Service sshd }
    Ok ("sshd: " + (Get-Service sshd).Status + ", StartupType=Automatic")

    $report.Add("USERNAME : $user")
    $report.Add("IS_ADMIN : $isAdmin")
    $report.Add("KEY_FILE : $file")
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
