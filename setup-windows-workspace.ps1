<#
    setup-windows-workspace.ps1
    End-to-end Windows workspace setup.

    What it does:
      1. Confirms git is installed (offers winget install if missing).
      2. Sets git user.name / user.email if not already configured.
      3. Detects your REAL Desktop path (handles OneDrive redirection).
      4. Clones klar-workspace  -> Desktop\CLAUDESCAPE
      5. Clones klar-health-docs -> Desktop\CLAUDESCAPE\EMR-PRODUCT
      6. Removes partial/incomplete folders from a failed earlier attempt
         before cloning fresh.
      7. Lists CLAUDESCAPE contents and prints the full path + a report.

    The first private clone will open a GitHub login in your browser —
    that's expected. Sign in and the script continues automatically.

    How to run (PowerShell):
      Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
      .\setup-windows-workspace.ps1
#>

$ErrorActionPreference = 'Stop'

$GitName  = 'Dunal Riveland'
$GitEmail = 'dunal229@gmail.com'

$Repos = @(
    @{ Folder = 'CLAUDESCAPE'; Url = 'https://github.com/dunal229/klar-workspace.git';   Parent = $null }
    @{ Folder = 'EMR-PRODUCT'; Url = 'https://github.com/dunal229/klar-health-docs.git'; Parent = 'CLAUDESCAPE' }
)

$report = [System.Collections.Generic.List[string]]::new()
function Ok($m)   { Write-Host "[ OK ] $m"   -ForegroundColor Green; $report.Add("OK   : $m") }
function Info($m) { Write-Host "[INFO] $m"    -ForegroundColor Cyan }
function Fail($m) { Write-Host "[FAIL] $m"    -ForegroundColor Red;   $report.Add("FAIL : $m") }

# ---------------------------------------------------------------------------
# 1. Confirm git is installed
# ---------------------------------------------------------------------------
function Ensure-Git {
    $git = Get-Command git -ErrorAction SilentlyContinue
    if ($git) {
        Ok ("git installed: " + (git --version))
        return
    }
    Info 'git not found. Attempting install via winget...'
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements
        # Refresh PATH for this session so git is usable immediately.
        $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' +
                    [System.Environment]::GetEnvironmentVariable('Path','User')
        if (Get-Command git -ErrorAction SilentlyContinue) {
            Ok ("git installed via winget: " + (git --version))
            return
        }
    }
    throw 'git is not installed and automatic install failed. Install from https://git-scm.com/download/win, reopen PowerShell, and re-run this script.'
}

# ---------------------------------------------------------------------------
# 2. Configure git identity if missing
# ---------------------------------------------------------------------------
function Ensure-GitIdentity {
    $curName  = (git config --global user.name)  2>$null
    $curEmail = (git config --global user.email) 2>$null

    if ([string]::IsNullOrWhiteSpace($curName)) {
        git config --global user.name $GitName
        Ok "Set git user.name  -> $GitName"
    } else {
        Ok "git user.name already set -> $curName (left unchanged)"
    }

    if ([string]::IsNullOrWhiteSpace($curEmail)) {
        git config --global user.email $GitEmail
        Ok "Set git user.email -> $GitEmail"
    } else {
        Ok "git user.email already set -> $curEmail (left unchanged)"
    }
}

# ---------------------------------------------------------------------------
# 3. Detect the REAL Desktop path (OneDrive-aware)
# ---------------------------------------------------------------------------
function Get-DesktopPath {
    # GetFolderPath respects the User Shell Folders redirect (incl. OneDrive).
    $desktop = [Environment]::GetFolderPath('Desktop')

    if ([string]::IsNullOrWhiteSpace($desktop) -or -not (Test-Path $desktop)) {
        # Fall back to the registry value and expand any env vars it contains.
        $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders'
        $raw = (Get-ItemProperty -Path $key -Name 'Desktop' -ErrorAction SilentlyContinue).Desktop
        if ($raw) { $desktop = [Environment]::ExpandEnvironmentVariables($raw) }
    }
    if ([string]::IsNullOrWhiteSpace($desktop) -or -not (Test-Path $desktop)) {
        # Last resort: classic profile Desktop.
        $desktop = Join-Path $env:USERPROFILE 'Desktop'
    }
    if (-not (Test-Path $desktop)) {
        throw "Could not locate a valid Desktop folder (tried: '$desktop')."
    }
    return (Resolve-Path $desktop).Path
}

# ---------------------------------------------------------------------------
# Clone helper: deletes partial folders, skips already-complete clones.
# ---------------------------------------------------------------------------
function Clone-Repo {
    param([string]$Url, [string]$TargetPath)

    if (Test-Path $TargetPath) {
        $isGoodRepo = $false
        if (Test-Path (Join-Path $TargetPath '.git')) {
            Push-Location $TargetPath
            try {
                git rev-parse --is-inside-work-tree *> $null
                if ($LASTEXITCODE -eq 0) { $isGoodRepo = $true }
            } catch {} finally { Pop-Location }
        }
        if ($isGoodRepo) {
            Ok "Already cloned, skipping: $TargetPath"
            return
        }
        Info "Removing partial/incomplete folder from earlier attempt: $TargetPath"
        Remove-Item -LiteralPath $TargetPath -Recurse -Force
    }

    Info "Cloning $Url"
    Info '  -> if a GitHub login opens in your browser, sign in; the script will continue.'
    git clone $Url $TargetPath
    if ($LASTEXITCODE -ne 0) { throw "git clone failed for $Url" }
    Ok "Cloned -> $TargetPath"
}

# ===========================================================================
# Run
# ===========================================================================
try {
    Ensure-Git
    Ensure-GitIdentity

    $desktop = Get-DesktopPath
    Ok "Detected Desktop: $desktop"

    $claudescape = Join-Path $desktop 'CLAUDESCAPE'

    foreach ($r in $Repos) {
        $target = if ($r.Parent) { Join-Path (Join-Path $desktop $r.Parent) $r.Folder }
                  else            { Join-Path $desktop $r.Folder }
        Clone-Repo -Url $r.Url -TargetPath $target
    }

    Write-Host ''
    Write-Host "===== CLAUDESCAPE contents ($claudescape) =====" -ForegroundColor Yellow
    Get-ChildItem -Force $claudescape | Select-Object Mode, LastWriteTime, Length, Name | Format-Table -AutoSize

    $report.Add("PATH : $claudescape")
}
catch {
    Fail $_.Exception.Message
}
finally {
    Write-Host ''
    Write-Host '===== REPORT =====' -ForegroundColor Yellow
    $report | ForEach-Object { Write-Host $_ }
    Write-Host '=================='
}
