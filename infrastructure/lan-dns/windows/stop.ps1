#Requires -RunAsAdministrator

# Stops CoreDNS started by start.ps1 and removes the HTTP portproxy rule.

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PidFile   = Join-Path $ScriptDir 'coredns.pid'

if (-not (Test-Path $PidFile)) {
    Write-Host 'CoreDNS does not appear to be running (no coredns.pid found).'
} else {
    $savedPid = Get-Content $PidFile -ErrorAction SilentlyContinue
    if (-not $savedPid) {
        Write-Host 'coredns.pid is empty.'
        Remove-Item $PidFile -Force
    } else {
        $proc = Get-Process -Id $savedPid -ErrorAction SilentlyContinue
        if ($proc -and $proc.Name -eq 'coredns') {
            Stop-Process -Id $savedPid -Force
            Write-Host "CoreDNS stopped (PID $savedPid)."
        } else {
            Write-Host "CoreDNS process (PID $savedPid) is not running."
        }
        Remove-Item $PidFile -Force
    }
}

$null = & netsh interface portproxy delete v4tov4 listenaddress=0.0.0.0 listenport=80 2>&1
Write-Host 'HTTP portproxy removed.'
