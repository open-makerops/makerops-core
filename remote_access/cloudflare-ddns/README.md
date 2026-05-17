# cloudflare-ddns — Dynamic DNS Updater

cloudflare-ddns automatically keeps your Cloudflare DNS records pointed at your host's current public IP. It runs as a background container, polling on a configurable schedule, and supports both IPv4 (A records) and IPv6 (AAAA records).

- **Docker image:** `timothyjmiller/cloudflare-ddns`
- **Docker Hub:** <https://hub.docker.com/r/timothyjmiller/cloudflare-ddns>
- **GitHub:** <https://github.com/timothyjmiller/cloudflare-ddns>

---

## Setup

### 1. Create a Cloudflare API token

Go to <https://dash.cloudflare.com/profile/api-tokens> and create a token with:

- **Permissions:** Zone → DNS → Edit
- **Zone resources:** Include → All zones (or restrict to specific zones)

### 2. Create `.env`

```env
CLOUDFLARE_API_TOKEN=your-token-here
DOMAINS=example.com,www.example.com
```

See the [`.env` Reference](#env-reference) section below for all options.

### 3. Start

```bash
./start.sh
```

The container will perform an initial update immediately (if `UPDATE_ON_START` is set) and then update on the configured schedule (default: every 5 minutes).

---

## Scripts

### `./start.sh`

Validates that `CLOUDFLARE_API_TOKEN` and at least one domain variable are set, pulls the image, and starts the container.

```bash
./start.sh
```

### `./stop.sh`

Stops the container. No data is lost — re-running `./start.sh` resumes updates.

```bash
./stop.sh
```

### `./teardown.sh`

Interactive full teardown: shows what will be removed, prompts for confirmation, then removes the container and image. No volumes to delete — this service is stateless.

```bash
./teardown.sh
```

---

## Files

| File | Purpose |
| --- | --- |
| `.env` | API token and domain configuration |
| `docker-compose.yml` | Single-container stack definition |
| `start.sh` | Start with pre-flight validation |
| `stop.sh` | Stop the container |
| `teardown.sh` | Full wipe with confirmation |

---

## `.env` Reference

| Variable | Default | Description |
| --- | --- | --- |
| `CLOUDFLARE_API_TOKEN` | **required** | API token with Zone:DNS:Edit permission |
| `DOMAINS` | **required** | Comma-separated domains for both A and AAAA records |
| `IP4_DOMAINS` | — | IPv4-only domain list (overrides `DOMAINS` for A records) |
| `IP6_DOMAINS` | — | IPv6-only domain list (overrides `DOMAINS` for AAAA records) |
| `IP6_PROVIDER` | `cloudflare.trace` | IPv6 detection method; set to `none` to disable AAAA updates |
| `PROXIED` | `false` | Enable Cloudflare proxy (orange-cloud) on updated records |
| `UPDATE_CRON` | `@every 5m` | Update schedule as a cron expression or Go duration string |
| `TTL` | `1` | DNS record TTL in seconds; `1` = Cloudflare auto |

---

## Cheat Sheet

### Logs

```bash
docker compose -p cloudflare-ddns logs -f
docker logs cloudflare-ddns -f
```

### Force an immediate update

```bash
docker restart cloudflare-ddns
```

### Upgrade

```bash
./stop.sh
docker pull timothyjmiller/cloudflare-ddns:latest
./start.sh
```

---

## Architecture

```text
Host network (public IP detection)
  └─► cloudflare-ddns  (timothyjmiller/cloudflare-ddns:latest)
        ├─► Detects public IPv4 via ipify (or configured provider)
        ├─► Detects public IPv6 via cloudflare.trace (or configured provider)
        └─► Updates A / AAAA records via Cloudflare DNS API
```

The container uses `network_mode: host` so it can observe the real public interface of the host rather than a Docker bridge address.
