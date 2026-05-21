# lan-dns — Windows Setup

On Windows, lan-dns runs [CoreDNS](https://coredns.io) as a native Windows process. No Docker, no WSL2 layer, no relay needed — CoreDNS binds directly to UDP/TCP port 53 on the Windows host and answers DNS queries from LAN clients.

Docker services continue to run in WSL2 as normal. Only the DNS component runs on the Windows side.

---

## Prerequisites

- **Windows 10 1803 or later** — `tar.exe` is built in; used to extract the CoreDNS download.
- **name-proxy running in WSL2** — lan-dns handles DNS only; name-proxy handles HTTP routing. Both must be running for LAN hostname access to work end-to-end.
- **Static LAN IP** — the host needs a fixed IP address so DNS answers stay valid. Assign one via your router's DHCP reservation table.
- **PowerShell script execution** — if scripts are blocked, allow them once (inspect the script before running):

  ```powershell
  Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
  ```

---

## How it works

```
LAN client
  └─► DNS query: n8n.central.home
        └─► CoreDNS (Windows, UDP/TCP port 53)
              └─► answers: 192.168.1.100  (this machine's LAN IP)

LAN client
  └─► HTTP GET http://n8n.central.home/
        └─► name-proxy (nginx, port 80, running in WSL2)
              └─► proxies to localhost:5678  (n8n in WSL2)
```

---

## Setup

### Step 1 — Disable Internet Connection Sharing (SharedAccess)

Windows' Internet Connection Sharing service (SharedAccess) holds UDP port 53 at startup. CoreDNS cannot bind to port 53 while SharedAccess is running.

Run once in **elevated PowerShell** from the `windows\` directory:

```powershell
.\scripts\disable-shared-access.ps1
```

This permanently disables SharedAccess. It does not affect normal internet access or Remote Desktop.

### Step 2 — Configure `.env`

```powershell
cd infrastructure\lan-dns\windows
copy .env.example .env
```

Edit `.env`:

| Variable | Description | Example |
| --- | --- | --- |
| `HOST_NAME` | Domain portion of hostnames — usually the computer's hostname. | `central` |
| `HOST_LAN_IP` | Static LAN IP of this machine. | `192.168.1.100` |
| `LAN_TLD` | Private TLD. See [Choosing a TLD](#choosing-a-tld). | `home` |
| `DNS_PORT` | Port CoreDNS listens on. Default `53`. | `53` |
| `UPSTREAM_DNS_1` / `UPSTREAM_DNS_2` | Fallback resolvers for all other queries. | `1.1.1.1` / `8.8.8.8` |

To find your LAN IP:

```powershell
(Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
    $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.*'
}).IPAddress
```

#### Choosing a TLD

| TLD | Notes |
| --- | --- |
| `.home` | Common convention for home/office networks |
| `.lan` | Common convention, widely used |
| `.internal` | IANA-reserved for private use |
| `.makerops` | Custom — guaranteed no public conflict |

**Do not use `.local`** — it is reserved by mDNS/Bonjour and causes resolution failures on Apple devices and Avahi.

### Step 3 — Open firewall ports

Run once in **elevated PowerShell**:

```powershell
.\scripts\open-firewall.ps1
```

This adds inbound rules for UDP/TCP 53 (DNS) and TCP 80 (HTTP) in Windows Defender Firewall.

### Step 4 — Start CoreDNS

```powershell
.\start.ps1
```

On the first run, `start.ps1` will:

1. Download CoreDNS v1.11.3 (Windows amd64, ~15 MB) from GitHub Releases.
2. Generate `Corefile` from the template using your `.env` values.
3. Start CoreDNS as a background Windows process.
4. Save the process PID to `coredns.pid`.
5. Configure a `netsh portproxy` rule forwarding TCP port 80 from the Windows LAN interface to name-proxy in WSL2.

CoreDNS starts automatically on subsequent runs (re-runs generate a fresh `Corefile`, restart CoreDNS, and refresh the portproxy rule with the current WSL2 IP).

> **Re-run `start.ps1` after every WSL2 restart.** WSL2's internal IP changes on each boot, so the portproxy rule must be updated. DNS (CoreDNS) is unaffected by this, but HTTP from LAN clients will stop working until the portproxy is refreshed.

Verify it is resolving from the host:

```powershell
Resolve-DnsName n8n.central.home -Server 127.0.0.1
# Expect: Address matching HOST_LAN_IP
```

Or if `dig` is available (via Git for Windows, WSL2, or other tools):

```bash
dig @127.0.0.1 n8n.central.home
```

### Step 5 — Configure the router (recommended)

Point the router's DHCP DNS server at `HOST_LAN_IP` so every LAN device resolves service names automatically. See the [main README](../README.md#step-5--configure-the-router-recommended) for router-specific instructions.

### Step 6 — Configure edge clients (without router changes)

Set `HOST_LAN_IP` as the primary DNS on each edge computer individually. See the [main README](../README.md#step-6--configure-edge-clients-without-router-changes).

---

## Stopping CoreDNS

```powershell
.\stop.ps1
```

CoreDNS is not registered as a Windows Service — it does not auto-start after reboot. Re-run `start.ps1` after each reboot, or register it as a scheduled task or NSSM service if you want automatic startup.

---

## Files

| File | Purpose |
| --- | --- |
| `.env.example` | Configuration template |
| `.env` | Local configuration (git-ignored) |
| `Corefile.template` | CoreDNS config template; `__PLACEHOLDER__` tokens substituted by `start.ps1` |
| `Corefile` | Generated config passed to CoreDNS (git-ignored) |
| `coredns.exe` | CoreDNS binary, downloaded by `start.ps1` (git-ignored) |
| `coredns.pid` | PID of the running CoreDNS process (git-ignored) |
| `coredns.log` | CoreDNS stdout log (git-ignored) |
| `coredns-err.log` | CoreDNS stderr log — startup messages and errors (git-ignored) |
| `start.ps1` | Download CoreDNS, generate Corefile, start process |
| `stop.ps1` | Stop CoreDNS |
| `scripts/disable-shared-access.ps1` | One-time: permanently disables SharedAccess to free UDP:53 |
| `scripts/open-firewall.ps1` | One-time: adds Windows Firewall rules for DNS and HTTP |

---

## Troubleshooting

### `Error: UDP port 53 is already in use`

SharedAccess is still running. Run `scripts\disable-shared-access.ps1` (elevated PowerShell) and then retry `start.ps1`.

If another process holds port 53 after SharedAccess is disabled:

```powershell
netstat -ano | Select-String ':53 '
# Note the PID, then:
Get-Process -Id <pid>
```

### CoreDNS exits immediately

Check the logs for errors:

```powershell
Get-Content coredns.log      # stdout
Get-Content coredns-err.log  # stderr — startup messages and errors
```

Common cause: Corefile syntax error from a special character in `HOST_NAME` or `LAN_TLD` that breaks the regex. Use only alphanumeric characters and hyphens.

### `Resolve-DnsName` returns correct IP on host but not from LAN clients

1. Confirm firewall rules are in place: `Get-NetFirewallRule -DisplayName 'makerops*'`
2. Confirm the LAN client's DNS is set to `HOST_LAN_IP`.
3. Confirm no other firewall (router ACL, third-party firewall) blocks UDP:53 inbound.

### LAN clients get a timeout on HTTP but DNS resolves correctly

WSL2 in NAT mode only exposes Docker's published ports on Windows `localhost`, not on the LAN-facing network interface. `start.ps1` configures a `netsh portproxy` rule to bridge this gap, but the rule becomes stale after a WSL2 restart (the WSL2 IP changes on each boot).

Re-run `start.ps1` to refresh the portproxy with the current WSL2 IP.

To check the current portproxy rules:

```powershell
netsh interface portproxy show all
```

To verify port 80 is reachable on the LAN interface from the host itself:

```powershell
Test-NetConnection -ComputerName <HOST_LAN_IP> -Port 80
# TcpTestSucceeded: True  → portproxy is working
# TcpTestSucceeded: False → portproxy is missing or stale; re-run start.ps1
```

### HTTP returns `502 Bad Gateway`

DNS resolved and the portproxy is working, but name-proxy cannot reach the target service. The service is not running in WSL2. Start it and retry.
