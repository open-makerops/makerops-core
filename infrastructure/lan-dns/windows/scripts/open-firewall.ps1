#Requires -RunAsAdministrator

# Opens Windows Defender Firewall rules to allow DNS (UDP/TCP 53) and HTTP (TCP 80)
# traffic inbound from the LAN so edge clients can reach CoreDNS and name-proxy.
#
# Run once. Rules persist across reboots.
# Safe to re-run -- existing rules are replaced, not duplicated.

$ruleDnsUdp = 'makerops-lan-dns-udp'
$ruleDnsTcp = 'makerops-lan-dns-tcp'
$ruleHttp   = 'makerops-name-proxy-http'

foreach ($rule in @($ruleDnsUdp, $ruleDnsTcp, $ruleHttp)) {
    Remove-NetFirewallRule -Name $rule -ErrorAction SilentlyContinue
}

New-NetFirewallRule -Name $ruleDnsUdp -DisplayName 'makerops lan-dns UDP' `
    -Direction Inbound -Protocol UDP -LocalPort 53 -Action Allow | Out-Null

New-NetFirewallRule -Name $ruleDnsTcp -DisplayName 'makerops lan-dns TCP' `
    -Direction Inbound -Protocol TCP -LocalPort 53 -Action Allow | Out-Null

New-NetFirewallRule -Name $ruleHttp -DisplayName 'makerops name-proxy HTTP' `
    -Direction Inbound -Protocol TCP -LocalPort 80 -Action Allow | Out-Null

Write-Host 'Firewall rules created:'
Write-Host '  UDP 53  -- DNS queries from LAN clients'
Write-Host '  TCP 53  -- DNS over TCP from LAN clients'
Write-Host '  TCP 80  -- HTTP from LAN clients to name-proxy'
Write-Host ''
Write-Host 'Next: start CoreDNS.'
Write-Host '  .\start.ps1'
