#Requires -RunAsAdministrator

# One-time setup: permanently disables Internet Connection Sharing (SharedAccess),
# which holds UDP:53 on Windows and prevents CoreDNS from binding to that port.
#
# SharedAccess is a Windows service that provides DNS proxy for devices sharing
# this machine's internet connection. Disabling it only affects ICS functionality;
# normal internet access and remote desktop are not affected.
#
# Run once before running start.ps1 for the first time.
# Re-run is not needed across reboots once disabled.

$svc = Get-Service -Name SharedAccess -ErrorAction SilentlyContinue
if (-not $svc) {
    Write-Host 'SharedAccess service not found -- nothing to do.'
    exit 0
}

if ($svc.Status -eq 'Stopped' -and $svc.StartType -eq 'Disabled') {
    Write-Host 'SharedAccess is already disabled and stopped.'
    exit 0
}

Write-Host 'Disabling SharedAccess (Internet Connection Sharing)...'

Set-Service -Name SharedAccess -StartupType Disabled -ErrorAction Stop

if ($svc.Status -ne 'Stopped') {
    try {
        Stop-Service -Name SharedAccess -Force -ErrorAction Stop
    } catch {
        Write-Host 'Stop-Service failed, trying sc.exe...' -ForegroundColor Yellow
        & sc.exe stop SharedAccess | Out-Null
    }

    $freed = $false
    for ($i = 1; $i -le 5; $i++) {
        Start-Sleep -Seconds 1
        $udp53 = (& netstat -ano 2>$null) | Where-Object { $_ -match 'UDP\s.*:53\s' }
        if (-not $udp53) { $freed = $true; break }
        Write-Host "Waiting for UDP:53 to be released... ($i/5)"
    }

    if (-not $freed) {
        Write-Host ''
        Write-Host 'Warning: UDP:53 is still in use after stopping SharedAccess.' -ForegroundColor Yellow
        Write-Host 'Another process may be holding the port:'
        & netstat -ano 2>$null | Where-Object { $_ -match 'UDP\s.*:53\s' }
        Write-Host ''
        Write-Host 'Investigate the PID above before running start.ps1.'
        exit 1
    }
}

Write-Host 'SharedAccess disabled and stopped.'
Write-Host ''
Write-Host 'Next: configure .env, then run scripts\open-firewall.ps1.'
Write-Host '  copy .env.example .env'
Write-Host '  (edit .env with HOST_NAME, HOST_LAN_IP, LAN_TLD)'
Write-Host '  .\scripts\open-firewall.ps1'
