# Environment Variable Conventions

Common patterns and standards shared across all service `.env` files in this stack.

---

## Timezone (`TZ`, `GENERIC_TIMEZONE`, `TIMEZONE`)

Set to any IANA timezone database name. All services in this stack default to `America/Chicago`.

Full list: <https://en.wikipedia.org/wiki/List_of_tz_database_time_zones>

Some services use multiple vars for the same concept:
- `TZ` — controls the container OS clock and most applications
- `GENERIC_TIMEZONE` — n8n-specific; used by Schedule Trigger nodes
- `TIMEZONE` — FreeScout-specific alias

All three should be set to the same value when present.

---

## File Ownership (`PUID` / `PGID`)

Used by [LinuxServer.io](https://linuxserver.io) images (BookStack in this stack) to set the UID/GID that the application process runs as inside the container. This controls which user owns files written to bind-mounted volumes.

Default `1000:1000` matches the first non-root user on most Linux hosts.

Reference: <https://docs.linuxserver.io/general/understanding-puid-and-pgid>

To find your host UID/GID: `id -u && id -g`

---

## Data Path Variables (`*_DATA_PATH`)

Every service exposes optional `*_DATA_PATH` variables that override where Docker stores persistent data on the host. When unset, data lands in subdirectories relative to the `docker-compose.yml` file (e.g. `./data/postgres`).

Override these when:
- You want to store data on a separate disk or mount point
- You need an absolute path for backup tooling
- You are migrating data from another location

Example: `INVENTREE_DB_DATA_PATH=/mnt/data/inventree/postgres`

Leave unset to use the service-local defaults shown in each `.env` file.

---

## Secret Generation

Services generate secrets automatically on first run via `start.sh`, but you can pre-generate them with:

```sh
# 64-character hex (32 bytes) — for encryption keys, Django SECRET_KEY
openssl rand -hex 32

# 32-character hex (16 bytes) — for shorter tokens
openssl rand -hex 16

# Laravel APP_KEY format
php artisan key:generate --show
# or without PHP: echo "base64:$(openssl rand -base64 32)"
```

### Never-change-after-first-run keys

The following keys encrypt data at rest. **Changing them after the first successful start will make all encrypted data unreadable** (stored credentials, tokens, attachments):

| Service | Variable |
|---------|----------|
| n8n | `N8N_ENCRYPTION_KEY` |
| BookStack | `APP_KEY` |
| Invoice Ninja | `APP_KEY` |
| Plane | `SECRET_KEY` |
| trigger.dev | `ENCRYPTION_KEY` |

Back these up immediately after first start using `push_envs.sh`.

---

## Admin Credential Defaults

Stack-wide standard for initial admin accounts (first-run only; change after setup):

| Field | Default |
|-------|---------|
| Email | `admin@example.com` |
| Username | `admin` |
| Password | service-specific (see individual `.env`) |

Services where the admin account is created through the UI (n8n, Plane) or via magic link (trigger.dev) do not use these env vars.

---

## Environment File Backup

Local `.env` files contain secrets and are excluded from the main git repository (see `.gitignore`). Use the provided scripts to back them up encrypted:

```sh
# Encrypt and push all .env files to a private GitHub Gist
./push_envs.sh

# Pull and decrypt all .env files from GitHub Gist
./pull_envs.sh
```

Encryption uses `age` with your SSH ed25519 key. The Gist URL is stored in `.envs-gist.conf` (also gitignored).

See `push_envs.sh` and `pull_envs.sh` in the project root for details.

---

## SMTP / Email (Optional, All Services)

Most services support optional SMTP configuration for sending notifications, password resets, and invite links. Without it, email is either logged to the container console or silently dropped.

Variable naming differs per service (see individual `.env` files), but the values are the same:

| Concept | Typical value |
|---------|--------------|
| Host | `smtp.example.com` or `mail.example.com` |
| Port | `587` (STARTTLS), `465` (SSL), `25` (plain) |
| Encryption | `tls` / `ssl` / `none` (varies by service) |
| Username | your SMTP login (often your email address) |
| Password | your SMTP password or app-specific password |
| From address | `noreply@yourdomain.com` |

Gmail users: create an [App Password](https://support.google.com/accounts/answer/185833) — regular passwords are rejected.

All SMTP sections in this stack are commented out by default. Uncomment and fill in to enable.
