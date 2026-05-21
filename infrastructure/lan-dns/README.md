# lan-dns — LAN Hostname Resolution

lan-dns makes every service in the makerops-core stack reachable by name from any computer on the LAN, without requiring each edge computer to remember port numbers.

Once configured, any edge client pointed at this host for DNS can access services like:

```
http://n8n.central.home
http://outline.central.home
http://plane.central.home
```

…where `central` is the host computer name and `home` is the chosen private TLD — both configurable.

This is an internal service. On **Linux and macOS** it runs dnsmasq in Docker. On **Windows**, it runs [CoreDNS](https://coredns.io) as a native Windows process — see [windows/README.md](windows/README.md) for the Windows-specific setup guide.

It complements [name-proxy](../name-proxy/README.md), which handles routing requests to the correct service port.

---

## How it works

```
Edge client
  └─► DNS query: n8n.central.home
        └─► lan-dns (dnsmasq, port 53)
              └─► answers: 192.168.1.100  (the host's LAN IP)

Edge client
  └─► HTTP GET http://n8n.central.home/
        └─► name-proxy (nginx, port 80) on 192.168.1.100
              └─► proxies to localhost:5678  (n8n)
```

**lan-dns** answers DNS queries for `*.HOST_NAME.LAN_TLD` with the host's LAN IP. All other queries are forwarded to public resolvers (Cloudflare, Google) so normal internet access is unaffected.

**name-proxy** (already part of the stack) accepts those incoming HTTP requests on port 80 and routes by service name subdomain to the correct local port. It requires no changes for LAN traffic — the existing wildcard routing handles it.

---

## Prerequisites

Before starting:

1. **Static LAN IP** — the host needs a fixed IP address on the LAN so DNS answers stay valid. Assign a static IP either in your router's DHCP reservation table (preferred) or via the host OS network settings.

2. **name-proxy running** — lan-dns handles DNS only; name-proxy handles HTTP routing. Both must be running for LAN hostname access to work end-to-end. Start name-proxy first if it is not already up:

   ```bash
   cd ../name-proxy && ./start.sh
   ```

---

## Setup

### Step 1 — Configure `.env`

```bash
cd makerops-core/infrastructure/lan-dns
cp .env.example .env
```

Edit `.env`:

| Variable | Description | Example |
| --- | --- | --- |
| `HOST_NAME` | The domain component of your hostnames — usually the computer's hostname. | `central` |
| `HOST_LAN_IP` | The static LAN IP of this machine. | `192.168.1.100` |
| `LAN_TLD` | Private TLD. See [Choosing a TLD](#choosing-a-tld). | `home` |
| `DNS_PORT` | Host port dnsmasq listens on. Default `53`. | `53` |
| `UPSTREAM_DNS_1` / `UPSTREAM_DNS_2` | Fallback resolvers for all other queries. | `1.1.1.1` / `8.8.8.8` |

To find your current LAN IP:

```bash
ip route get 1 | awk '{print $7; exit}'
```

#### Choosing a TLD

Use one of these safe private TLDs that do not conflict with public DNS or system-reserved domains:

| TLD | Notes |
| --- | --- |
| `.home` | Common convention for home/office networks |
| `.lan` | Common convention, widely used |
| `.internal` | IANA-reserved for private use |
| `.makerops` | Custom — guaranteed no public conflict |

**Do not use `.local`** — it is reserved by mDNS/Bonjour (used by Apple devices, Avahi) and will cause resolution failures or unpredictable behaviour on the LAN.

---

### Step 2 — Resolve port 53 conflicts (Linux only)

On Ubuntu/Debian, `systemd-resolved` listens on `127.0.0.53:53`, which prevents dnsmasq from binding to port 53. Check whether this applies:

```bash
sudo ss -tulpn | grep ':53'
```

If you see `systemd-resolved` or `127.0.0.53`:

```bash
# Disable the stub listener (does not disable systemd-resolved itself)
sudo sed -i 's/#DNSStubListener=yes/DNSStubListener=no/' /etc/systemd/resolved.conf
sudo systemctl restart systemd-resolved
```

Verify the port is now free:

```bash
sudo ss -tulpn | grep ':53'
# Should return no output, or show only your expected processes
```

---

### Step 3 — Open firewall ports

The host machine needs to accept DNS (port 53) and HTTP (port 80) traffic from the LAN.

> **Windows users:** Stop here and follow [windows/README.md](windows/README.md) instead. The Windows setup uses CoreDNS running natively on Windows — the steps below apply only to Linux and macOS.

Run the script for your host OS from the `infrastructure/lan-dns/` directory:

| OS | Script | How to run |
| --- | --- | --- |
| Linux | `scripts/open-firewall-linux.sh` | `./scripts/open-firewall-linux.sh <subnet>` |
| macOS | `scripts/open-firewall-macos.sh` | `./scripts/open-firewall-macos.sh` |

To find your LAN subnet (Linux):

```bash
ip route | grep 'src' | head -5
# Look for a line like: 192.168.1.0/24 dev eth0 ...
```

#### macOS note

Docker Desktop publishes ports directly on the host interface and registers its own firewall rules — the script verifies what is listening and exits. If you use a third-party firewall (Little Snitch, Lulu, etc.), add inbound rules manually for UDP/TCP 53 and TCP 80 from your LAN subnet.

---

### Step 4 — Start lan-dns

```bash
./start.sh
```

`start.sh` generates `dnsmasq.conf` from the template and starts the container.

Verify it is resolving correctly from the host:

```bash
dig @127.0.0.1 n8n.central.home
# Expect: ANSWER SECTION with your HOST_LAN_IP
```

If `dig` is not installed: `sudo apt install dnsutils`

---

### Step 5 — Configure the router (recommended)

Configuring the router means every device on the LAN can immediately use LAN hostnames without any per-device setup. This is the "set up once" path.

Two approaches are available depending on what your router supports.

#### Option A — Conditional forwarding (preferred — `.home` traffic only)

Some routers support forwarding only specific domains to a given DNS server, leaving all other traffic unaffected. This is the cleanest approach.

**Router-specific instructions:**

<details>
<summary>OpenWRT / LEDE</summary>

Network → DHCP and DNS → DNS forwardings:

```
/home/192.168.1.100
```

This forwards only `.home` queries to the host, leaving all other DNS unchanged. Replace `home` with your `LAN_TLD`.

</details>

<details>
<summary>pfSense / OPNsense</summary>

Services → DNS Resolver → General Settings → Custom options:

```
server=/home/192.168.1.100
```

This is a conditional forward: only `.home` queries go to the host.

</details>

<details>
<summary>Unifi / EdgeRouter</summary>

Config → Services → DNS → Forwarding → Name Server / Domain: add `home` → `192.168.1.100`.

</details>

#### Option B — Host as primary DNS (standard home routers)

Most consumer routers — including TP-Link Archer models — do not support per-domain conditional forwarding in their stock firmware. The only DNS setting available is a single primary/secondary server applied to all traffic.

In this case, set the **Primary DNS** in LAN → DHCP Settings to `HOST_LAN_IP` and the secondary to `1.1.1.1` or `8.8.8.8`.

All DNS traffic from LAN clients is routed through the host, which then forwards non-`.LAN_TLD` queries directly to Cloudflare/Google. The host adds one lightweight forwarding hop for general internet queries — this is not a meaningful bottleneck for home or small office networks, as the DNS server handles query forwarding in microseconds.

If you want per-domain forwarding without replacing your router's firmware, see [Step 6](#step-6--configure-edge-clients-without-router-changes) to configure individual clients instead.

---

### Step 6 — Configure edge clients (without router changes)

Use this approach if your router does not support per-domain conditional forwarding (e.g. standard TP-Link Archer firmware). Each client is configured to send only `.LAN_TLD` queries to the host, leaving all other DNS unaffected — no bottleneck, no routing of general internet lookups through the host.

#### Linux

Edit `/etc/systemd/resolved.conf`:

```ini
[Resolve]
DNS=192.168.1.100
Domains=~home
```

Then restart:

```bash
sudo systemctl restart systemd-resolved
```

`Domains=~home` routes only `.home` queries to the host; all other DNS continues normally.

#### macOS

System Settings → Network → [Your connection] → Details → DNS → Add `192.168.1.100` as a DNS server.

Or from the terminal:

```bash
# Create a resolver for the private TLD only
sudo mkdir -p /etc/resolver
echo "nameserver 192.168.1.100" | sudo tee /etc/resolver/home
```

Replace `home` with your `LAN_TLD`.

#### Windows

Windows does not support native per-domain DNS routing for edge clients. Setting the host as the primary DNS sends all DNS traffic through it (same trade-off as Option B above, scoped to this one machine).

Settings → Network & Internet → [Ethernet or Wi-Fi] → Edit DNS → Manual → IPv4 → Preferred DNS: `192.168.1.100`, Secondary: `1.1.1.1`.

Or via PowerShell (run as Administrator):

```powershell
# List network adapters
Get-NetAdapter

# Set DNS (replace "Ethernet" with your adapter name)
Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses ("192.168.1.100","1.1.1.1")
```

---

## Verification

From any configured edge client:

```bash
# DNS resolution
dig n8n.central.home        # Should return HOST_LAN_IP
ping n8n.central.home       # Should reach the host

# HTTP access (name-proxy must be running)
curl -si http://n8n.central.home/ | head -5
# Expect: HTTP/1.1 200 OK or a redirect from the n8n service
```

From the host itself (using the container's DNS):

```bash
dig @127.0.0.1 -p 53 n8n.central.home
```

---

## Service URLs produced

With `HOST_NAME=central` and `LAN_TLD=home`:

| URL | Service |
|---|---|
| `http://n8n.central.home` | n8n — Workflow Automation |
| `http://outline.central.home` | Outline — Knowledge Base |
| `http://plane.central.home` | Plane — Project Management |
| `http://trigger.central.home` | trigger.dev — Background Jobs |
| `http://freescout.central.home` | FreeScout — Help Desk |
| `http://invoiceninja.central.home` | Invoice Ninja — Accounting |
| `http://inventree.central.home` | InvenTree — Inventory Management |
| `http://ollama.central.home` | Ollama — LLM Inference API |
| `http://comfyui.central.home` | ComfyUI — Image Generation |
| `http://wg.central.home` | WireGuard (wg-easy) — VPN Management |

The subdomain must match the service name as configured in name-proxy. The domain (`central`) and TLD (`home`) are what you set in `.env`.

---

## Service URL configuration (advanced)

Most services work via LAN proxy without reconfiguration. The proxy passes the original `Host` header to the service, and services respond through the proxy transparently.

A few services generate absolute URLs internally (links in emails, webhook endpoints, OAuth callbacks). These will reference `localhost` until the service's own `HOST` or `URL` variable is updated to match the LAN hostname. This is a cosmetic issue for most services but functional for webhook-reliant workflows in n8n or trigger.dev.

If a service returns `400 Bad Request` when accessed via LAN hostname, it is likely validating the `Host` header against its configured URL. Update the relevant variable in that service's `.env`:

| Service | Variable | Example LAN value |
|---|---|---|
| n8n | `N8N_HOST`, `WEBHOOK_URL` | `n8n.central.home` |
| Outline | `URL` | `http://outline.central.home` |
| FreeScout | `SITE_URL` | `http://freescout.central.home` |
| Plane | `WEB_URL`, `APP_DOMAIN` | `http://plane.central.home` |
| trigger.dev | `TRIGGER_DOMAIN` | `trigger.central.home:80` |

Restart the affected service after changing its `.env`.

---

## Scripts

### `./start.sh`

Creates `.env` from `.env.example` on first run (and exits, prompting you to fill it in). On subsequent runs, generates `dnsmasq.conf` from the template and starts the container.

```bash
./start.sh
```

### `./stop.sh`

Stops the container. No data is persisted.

```bash
./stop.sh
```

---

## Files

| File | Purpose |
|---|---|
| `.env.example` | Configuration template |
| `.env` | Local configuration (git-ignored) |
| `dnsmasq.conf.template` | dnsmasq config template; `${VAR}` placeholders substituted by `start.sh` |
| `dnsmasq.conf` | Generated config mounted into the container (git-ignored) |
| `Dockerfile` | Builds dnsmasq from Alpine — no dependency on third-party images |
| `docker-compose.yml` | Single-container stack definition |
| `start.sh` | Generate config and start |
| `stop.sh` | Stop |
| `scripts/open-firewall-linux.sh` | Opens ufw ports 53 and 80 for a given LAN subnet |
| `scripts/open-firewall-macos.sh` | Verifies port availability on macOS (Docker Desktop handles rules) |
| `windows/` | Windows-specific setup using CoreDNS — see [windows/README.md](windows/README.md) |

---

## Troubleshooting

**`Error starting userland proxy: listen tcp4 0.0.0.0:53: bind: address already in use`**

Port 53 is occupied. On Linux this is usually `systemd-resolved` — see [Step 2](#step-2--resolve-port-53-conflicts-linux-only). On other systems, check what holds port 53:

```bash
sudo ss -tulpn | grep ':53'
```

**`dig` returns `SERVFAIL` or no answer**

1. Verify the container is running: `docker ps | grep lan-dns`
2. Check dnsmasq logs: `docker compose -p lan-dns logs`
3. Confirm the host firewall allows port 53 from the LAN.
4. Confirm the edge client's DNS is actually pointing to `HOST_LAN_IP` (not cached from a previous setting).

**HTTP returns `502 Bad Gateway`**

DNS is resolving correctly but name-proxy cannot reach the target service. The service is not running. Start it and retry.

**HTTP returns nginx 404 (no matching virtual host)**

The subdomain in the URL does not match any service name. Check the list of valid service names in [Service URLs produced](#service-urls-produced). The subdomain is case-sensitive.

**Service returns `400 Bad Request`**

The service is validating the `Host` header. See [Service URL configuration](#service-url-configuration-advanced).
