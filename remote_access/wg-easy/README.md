# wg-easy — WireGuard VPN

wg-easy is a self-hosted WireGuard VPN server with a web-based management UI. It handles key generation, client configuration, QR codes, and connection statistics through a browser interface.

- **Home page / docs:** <https://wg-easy.github.io/wg-easy/>
- **GitHub:** <https://github.com/wg-easy/wg-easy>
- **Docker image:** `ghcr.io/wg-easy/wg-easy`

---

## Attribution

**wg-easy** is open-source software developed and maintained by the wg-easy contributors. It is made freely available under the [AGPL-3.0 license](https://github.com/wg-easy/wg-easy/blob/master/LICENSE). WireGuard® is a registered trademark of Jason A. Donenfeld.

---

## Local Access

| | |
| --- | --- |
| **Web UI** | <http://localhost:8820> |
| **VPN endpoint** | UDP port 51820 |

---

## Setup

### Before first start

1. Edit `.env` and set:
   - `INIT_ENABLED=true`
   - `INIT_PASSWORD` — the admin account password
   - `INIT_HOST` — the **public** IP address or hostname VPN clients will use to connect (e.g. `vpn.example.com` or your WAN IP)
   - Review `INIT_DNS`, `INIT_IPV4_CIDR`, and `INIT_ALLOWED_IPS` (defaults are sensible for a full-tunnel setup)

2. Run `./start.sh`. The container bootstraps the admin account and WireGuard config on first start.

3. After the first successful start, set `INIT_ENABLED=false` in `.env` and clear `INIT_PASSWORD`. The config is now persisted to the `wg_data` Docker volume and will survive restarts without the INIT variables.

> **Security note:** `INIT_PASSWORD` is plain-text in `.env`. Clear it once setup is complete to avoid leaving credentials on disk.

### WSL2 compatibility

WireGuard requires kernel-level support (`SYS_MODULE` capability and IP forwarding sysctls). These may be partially unavailable in WSL2. If the container fails to start:

- Remove `SYS_MODULE` from `cap_add` in `docker-compose.yml`
- Comment out the `net.ipv6.*` sysctl lines if IPv6 is not needed
- Ensure the WSL2 kernel has WireGuard support (`modinfo wireguard` should succeed)

---

## Scripts

### `./start.sh`

Validates `.env` for obvious placeholder values (if `INIT_ENABLED=true`), pulls the image, and starts the container.

```bash
./start.sh
```

### `./stop.sh`

Stops the container. The `wg_data` volume (all WireGuard keys and client configs) is preserved.

```bash
./stop.sh
```

### `./teardown.sh`

Interactive full teardown: shows what will be removed, prompts for confirmation, then deletes the container, volume, image, and network. **All VPN client configurations will stop working** after teardown.

```bash
./teardown.sh
```

---

## Files

| File | Purpose |
| --- | --- |
| `.env` | Port configuration and first-run setup variables |
| `docker-compose.yml` | Single-container stack definition |
| `start.sh` | Start / first-run validation |
| `stop.sh` | Stop (volume preserved) |
| `teardown.sh` | Full wipe with confirmation |

---

## `.env` Reference

| Variable | Default | Description |
| --- | --- | --- |
| `WG_UDP_PORT` | `51820` | Host UDP port for VPN traffic |
| `WG_UI_PORT` | `8820` | Host TCP port for the web UI |
| `INIT_ENABLED` | `false` | Enable unattended first-run setup |
| `INIT_USERNAME` | `admin` | Admin username |
| `INIT_PASSWORD` | *(required)* | Admin password — clear after setup |
| `INIT_HOST` | *(required)* | Public IP/hostname clients connect to |
| `INIT_PORT` | `51820` | WireGuard listen port (must match `WG_UDP_PORT`) |
| `INIT_DNS` | `1.1.1.1,8.8.8.8` | DNS servers pushed to clients |
| `INIT_IPV4_CIDR` | `10.8.0.0/24` | Internal VPN subnet |
| `INIT_IPV6_CIDR` | `fd42::/64` | Internal VPN IPv6 subnet |
| `INIT_ALLOWED_IPS` | `0.0.0.0/0,::/0` | Routes pushed to clients (`0.0.0.0/0` = full tunnel) |

---

## Architecture

```text
Browser / VPN clients
  ├─► localhost:8820  (TCP) → Web UI (client management, QR codes, stats)
  └─► <public IP>:51820 (UDP) → WireGuard VPN tunnel
          └─► wg-easy  (ghcr.io/wg-easy/wg-easy:15)
                └─► wg_data volume  (/etc/wireguard — keys + config)
```

---

## Cheat Sheet

### Logs

```bash
docker compose -p wg-easy logs -f
docker logs wg-easy -f
```

### Shell access

```bash
docker exec -it wg-easy sh
```

### Check WireGuard status inside the container

```bash
docker exec wg-easy wg show
```

### Backup VPN config

The entire VPN state (server keys, client configs) lives in the `wg_easy_wg_data` Docker volume. Back it up with:

```bash
docker run --rm -v wg_easy_wg_data:/data -v $(pwd):/backup alpine \
  tar czf /backup/wg-easy-backup.tar.gz -C /data .
```

### Upgrade

1. `./stop.sh`
2. `docker pull ghcr.io/wg-easy/wg-easy:15`
3. `./start.sh` — existing config in the volume is preserved

To pin a specific patch release, update the image tag in `docker-compose.yml`.

### Split tunnel vs. full tunnel

- **Full tunnel** (default): `INIT_ALLOWED_IPS=0.0.0.0/0,::/0` — all client traffic routes through the VPN.
- **Split tunnel**: set `INIT_ALLOWED_IPS` to only the subnets you want to route through the VPN (e.g. `10.0.0.0/8` to only reach internal services).

This setting is configured per-client in the web UI after setup; `INIT_ALLOWED_IPS` only sets the default for new clients.
