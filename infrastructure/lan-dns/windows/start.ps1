#Requires -RunAsAdministrator

# Starts CoreDNS on Windows to resolve *.HOST_NAME.LAN_TLD to HOST_LAN_IP.
# No Docker or WSL2 required -- CoreDNS runs as a native Windows process.
#
# First run: copies .env.example to .env and exits, prompting configuration.
# Subsequent runs: generates Corefile from template and starts CoreDNS.

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

$CoreDnsVersion = '1.11.3'
$CoreDnsExe     = Join-Path $ScriptDir 'coredns.exe'
$CoreDnsUrl     = "https://github.com/coredns/coredns/releases/download/v${CoreDnsVersion}/coredns_${CoreDnsVersion}_windows_amd64.tgz"
$PidFile        = Join-Path $ScriptDir 'coredns.pid'
$OutFile        = Join-Path $ScriptDir 'coredns.log'
$ErrFile        = Join-Path $ScriptDir 'coredns-err.log'
$EnvFile        = Join-Path $ScriptDir '.env'
$EnvExample     = Join-Path $ScriptDir '.env.example'
$CorefileTemplate = Join-Path $ScriptDir 'Corefile.template'
$Corefile       = Join-Path $ScriptDir 'Corefile'

# ─── First run: create .env ───────────────────────────────────────────────────

if (-not (Test-Path $EnvFile)) {
    Copy-Item $EnvExample $EnvFile
    Write-Host '.env created from .env.example'
    Write-Host 'Set HOST_NAME, HOST_LAN_IP, and LAN_TLD before continuing.'
    Write-Host 'Then re-run: .\start.ps1'
    exit 0
}

# ─── Parse .env ───────────────────────────────────────────────────────────────

$env_vars = @{}
foreach ($line in Get-Content $EnvFile) {
    if ($line -match '^\s*#' -or $line -match '^\s*$') { continue }
    $parts = $line -split '=', 2
    if ($parts.Count -eq 2) {
        $env_vars[$parts[0].Trim()] = $parts[1].Trim()
    }
}

$HOST_NAME      = $env_vars['HOST_NAME']
$HOST_LAN_IP    = $env_vars['HOST_LAN_IP']
$LAN_TLD        = $env_vars['LAN_TLD']
$DNS_PORT       = if ($env_vars['DNS_PORT']) { $env_vars['DNS_PORT'] } else { '53' }
$UPSTREAM_DNS_1 = if ($env_vars['UPSTREAM_DNS_1']) { $env_vars['UPSTREAM_DNS_1'] } else { '1.1.1.1' }
$UPSTREAM_DNS_2 = if ($env_vars['UPSTREAM_DNS_2']) { $env_vars['UPSTREAM_DNS_2'] } else { '8.8.8.8' }

# ─── Validate required variables ──────────────────────────────────────────────

$missing = @()
if (-not $HOST_NAME)   { $missing += 'HOST_NAME' }
if (-not $HOST_LAN_IP) { $missing += 'HOST_LAN_IP' }
if (-not $LAN_TLD)     { $missing += 'LAN_TLD' }

if ($missing.Count -gt 0) {
    $list = $missing -join ', '
    Write-Host "Error: the following variables are not set in .env: $list" -ForegroundColor Red
    exit 1
}

if ($LAN_TLD -eq 'local') {
    Write-Host 'Error: LAN_TLD=local conflicts with mDNS/Bonjour (.local is reserved).' -ForegroundColor Red
    Write-Host 'Use a different TLD such as lan, home, or internal.'
    exit 1
}

# ─── Download CoreDNS if absent ───────────────────────────────────────────────

if (-not (Test-Path $CoreDnsExe)) {
    Write-Host "CoreDNS not found. Downloading v${CoreDnsVersion}..."
    $tgz = Join-Path $ScriptDir 'coredns.tgz'
    try {
        Invoke-WebRequest -Uri $CoreDnsUrl -OutFile $tgz -UseBasicParsing
        & tar.exe -xzf $tgz -C $ScriptDir coredns.exe
        Remove-Item $tgz -Force
    } catch {
        Write-Host "Failed to download CoreDNS: $_" -ForegroundColor Red
        if (Test-Path $tgz) { Remove-Item $tgz -Force }
        exit 1
    }
    if (-not (Test-Path $CoreDnsExe)) {
        Write-Host 'CoreDNS executable not found after extraction.' -ForegroundColor Red
        exit 1
    }
    Write-Host 'CoreDNS downloaded.'
}

# ─── Check port 53 availability ───────────────────────────────────────────────

$port53 = (& netstat -ano 2>$null) | Where-Object { $_ -match "UDP\s.*:${DNS_PORT}\s" }
if ($port53) {
    Write-Host "Error: UDP port ${DNS_PORT} is already in use." -ForegroundColor Red
    Write-Host ''
    $port53 | ForEach-Object { Write-Host "  $_" }
    Write-Host ''
    Write-Host 'Run scripts\disable-shared-access.ps1 (as Administrator) to free port 53,'
    Write-Host 'then re-run this script.'
    exit 1
}

# ─── Generate Corefile from template ──────────────────────────────────────────

$HOST_NAME_REGEX = [Regex]::Escape($HOST_NAME)
$LAN_TLD_REGEX   = [Regex]::Escape($LAN_TLD)

$corefile_content = Get-Content $CorefileTemplate -Raw
$corefile_content = $corefile_content -replace '__DNS_PORT__',       $DNS_PORT
$corefile_content = $corefile_content -replace '__HOST_NAME_REGEX__', $HOST_NAME_REGEX
$corefile_content = $corefile_content -replace '__LAN_TLD_REGEX__',   $LAN_TLD_REGEX
$corefile_content = $corefile_content -replace '__HOST_LAN_IP__',     $HOST_LAN_IP
$corefile_content = $corefile_content -replace '__UPSTREAM_DNS_1__',  $UPSTREAM_DNS_1
$corefile_content = $corefile_content -replace '__UPSTREAM_DNS_2__',  $UPSTREAM_DNS_2

Set-Content -Path $Corefile -Value $corefile_content -NoNewline

# ─── Stop any existing CoreDNS instance ───────────────────────────────────────

if (Test-Path $PidFile) {
    $oldPid = Get-Content $PidFile -ErrorAction SilentlyContinue
    if ($oldPid) {
        $proc = Get-Process -Id $oldPid -ErrorAction SilentlyContinue
        if ($proc -and $proc.Name -eq 'coredns') {
            Write-Host "Stopping existing CoreDNS (PID $oldPid)..."
            Stop-Process -Id $oldPid -Force -ErrorAction SilentlyContinue
            Start-Sleep -Milliseconds 500
        }
    }
    Remove-Item $PidFile -Force
}

# ─── Start CoreDNS ────────────────────────────────────────────────────────────

Write-Host 'Starting CoreDNS...'
$proc = Start-Process -FilePath $CoreDnsExe `
    -ArgumentList '-conf', $Corefile `
    -WorkingDirectory $ScriptDir `
    -RedirectStandardOutput $OutFile `
    -RedirectStandardError  $ErrFile `
    -WindowStyle Hidden `
    -PassThru

Start-Sleep -Milliseconds 800

if ($proc.HasExited) {
    Write-Host 'CoreDNS exited immediately. Check logs for errors:' -ForegroundColor Red
    Write-Host "  coredns.log     (stdout):"
    Get-Content $OutFile -ErrorAction SilentlyContinue | Select-Object -Last 10
    Write-Host "  coredns-err.log (stderr):"
    Get-Content $ErrFile -ErrorAction SilentlyContinue | Select-Object -Last 10
    exit 1
}

Set-Content -Path $PidFile -Value $proc.Id

Write-Host "CoreDNS is running (PID $($proc.Id)) on port ${DNS_PORT}."

# ─── HTTP portproxy: Windows LAN interface → WSL2 name-proxy ──────────────────
#
# WSL2 in NAT mode only exposes Docker's published ports on Windows localhost,
# not on the LAN-facing interface. LAN clients hitting HOST_LAN_IP:80 get
# nothing without this portproxy rule.
#
# This rule must be refreshed every time WSL2 starts because the WSL2 IP
# changes on each boot.

Write-Host 'Configuring HTTP portproxy to WSL2...'
$wsl2ip = $null
try {
    $raw = & wsl hostname -I 2>$null
    if ($raw) { $wsl2ip = $raw.Trim().Split()[0] }
} catch {}

if ($wsl2ip) {
    $null = & netsh interface portproxy delete v4tov4 listenaddress=0.0.0.0 listenport=80 2>&1
    $null = & netsh interface portproxy add    v4tov4 listenaddress=0.0.0.0 listenport=80 `
        connectaddress=$wsl2ip connectport=80 2>&1
    Write-Host "  TCP port 80 --> WSL2 (${wsl2ip}):80"
} else {
    Write-Host '  Warning: WSL2 is not running -- HTTP portproxy not configured.' -ForegroundColor Yellow
    Write-Host '  Start WSL2, then re-run .\start.ps1 to set up the portproxy.'
}

Write-Host ''
Write-Host "  Resolves: *.${HOST_NAME}.${LAN_TLD} --> ${HOST_LAN_IP}"
Write-Host "  Example:  n8n.${HOST_NAME}.${LAN_TLD}"
Write-Host "            outline.${HOST_NAME}.${LAN_TLD}"
Write-Host ''
Write-Host 'Next steps:'
Write-Host '  1. Configure your router to use this machine as the DNS server for the LAN.'
Write-Host "     Set primary DNS to: ${HOST_LAN_IP}"
Write-Host '     (Or configure each edge client individually -- see windows\README.md Step 6.)'
Write-Host '  2. Start name-proxy in WSL2 (infrastructure/name-proxy/start.sh) if not already running.'
Write-Host ''
Write-Host "Verify: Resolve-DnsName n8n.${HOST_NAME}.${LAN_TLD} -Server ${HOST_LAN_IP}"
Write-Host "Logs:   Get-Content coredns.log -Wait      (stdout)"
Write-Host "        Get-Content coredns-err.log -Wait  (stderr / errors)"
Write-Host "Stop:   .\stop.ps1"
