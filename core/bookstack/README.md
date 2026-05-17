# BookStack — Wiki & Documentation

BookStack is an open-source, self-hosted wiki platform for organising and storing documentation. Content is structured as Books → Chapters → Pages, with a rich WYSIWYG editor, full-text search, and role-based permissions.

- **Home page:** https://www.bookstackapp.com
- **Docs:** https://www.bookstackapp.com/docs
- **GitHub:** https://github.com/BookStackApp/BookStack
- **Docker image:** https://docs.linuxserver.io/images/docker-bookstack

---

## Attribution

**BookStack** is open-source software developed and maintained by Dan Brown and the BookStack community. It is made freely available under the [MIT License](https://github.com/BookStackApp/BookStack/blob/development/LICENSE). The Docker image used here is packaged and maintained by the [LinuxServer.io](https://www.linuxserver.io) community, a separate volunteer organization that provides long-running, well-maintained Docker images for many popular self-hosted applications.

- **Support BookStack:** [GitHub Sponsors — ssddanbrown](https://github.com/sponsors/ssddanbrown)
- **Support LinuxServer.io:** [Open Collective](https://opencollective.com/linuxserver) · [GitHub Sponsors](https://github.com/sponsors/linuxserver)

BookStack does not currently offer an official cloud-hosted service. If you prefer not to manage the infrastructure yourself, a number of third-party managed hosting providers offer BookStack as a service — search "BookStack managed hosting" for current options.

---

## Local Access

| | |
|---|---|
| **URL** | http://localhost:6875 |
| **Username** | `admin@admin.com` |
| **Password** | `password` (default — change immediately after first login) |

The default credentials are set by the BookStack application itself on first database seed. They are not configurable in `.env`.

---

## Scripts

### `./start.sh`

On **first run**, auto-generates `APP_KEY` (a Laravel encryption key) and writes it into `.env`, then pulls images and starts the stack. Subsequent runs skip key generation.

```bash
./start.sh
```

First-run setup takes 30–60 seconds while BookStack seeds the database.

### `./stop.sh`

Stops all containers. Volumes (database + config) are preserved.

```bash
./stop.sh
```

### `./teardown.sh`

Interactive full teardown: lists what will be removed, prompts for confirmation, then deletes all containers, volumes, images, and networks.

```bash
./teardown.sh
```

To re-install completely fresh (new secrets too):

```bash
sed -i 's/^APP_KEY=.*/APP_KEY=/' .env
./teardown.sh
./start.sh
```

---

## Files

| File | Purpose |
|---|---|
| `.env` | App URL, database passwords, encryption key |
| `docker-compose.yml` | 2-container stack definition |
| `config/` | BookStack config and file uploads (bind-mounted into container) |
| `db_data/` | MariaDB data directory (bind-mounted into container) |
| `start.sh` | Start / first-run setup |
| `stop.sh` | Stop (volumes preserved) |
| `teardown.sh` | Full wipe with confirmation |

### `.env` — values of interest

| Variable | Value | Notes |
|---|---|---|
| `APP_URL` | `http://localhost:6875` | Must match the browser URL; changing it after first start breaks existing links |
| `APP_KEY` | *(generated)* | Laravel encryption key; **never change** after first start — sessions and encrypted data will be invalidated |
| `DB_PASSWORD` | `bookstack_secret` | MariaDB application user password |
| `MYSQL_ROOT_PASSWORD` | `root_secret` | MariaDB root password |
| `TZ` | `America/Chicago` | Timezone for the app and database |

> **Security note:** `DB_PASSWORD` and `MYSQL_ROOT_PASSWORD` in `.env` are plain-text defaults. Change them before first run if this instance is on a shared machine.

---

## Architecture

```
Browser
  └─► localhost:6875
        └─► bookstack  (LinuxServer BookStack — Nginx + PHP-FPM)
              └─► bookstack_db:3306  (MariaDB)
```

**Containers:**

| Container | Image | Role |
|---|---|---|
| `bookstack` | `lscr.io/linuxserver/bookstack:latest` | App server (Nginx + PHP-FPM) |
| `bookstack_db` | `lscr.io/linuxserver/mariadb:latest` | Database |

**Bind mounts (local directories):**

| Directory | Contents |
|---|---|
| `./config/` | BookStack configuration, uploaded files, generated assets |
| `./db_data/` | MariaDB data files |

These directories are created by the container on first run. Back them up to preserve all data.

---

## Cheat Sheet

### Logs

```bash
# All services
docker compose logs -f

# App only
docker logs bookstack -f

# Database only
docker logs bookstack_db -f
```

### Shell access

```bash
docker exec -it bookstack bash
docker exec -it bookstack_db bash
```

### Reset admin password

BookStack does not have a CLI for password reset. Use the built-in "Forgot password" flow, or reset via the database:

```bash
# Generate a bcrypt hash for 'newpassword'
docker exec bookstack php /app/www/artisan tinker --execute="echo bcrypt('newpassword');"

# Then update in the database
docker exec -it bookstack_db mysql -u bookstack -pbookstack_secret bookstack \
  -e "UPDATE users SET password='<hash>' WHERE email='admin@admin.com';"
```

### Run artisan commands

```bash
docker exec bookstack php /app/www/artisan <command>

# Examples:
docker exec bookstack php /app/www/artisan bookstack:regenerate-search
docker exec bookstack php /app/www/artisan cache:clear
```

### Back up data

```bash
# Database dump
docker exec bookstack_db mysqldump -u bookstack -pbookstack_secret bookstack > bookstack_backup.sql

# Uploaded files are in ./config/www/files/ and ./config/www/images/
```

### Upgrade BookStack

1. `./stop.sh`
2. `docker pull lscr.io/linuxserver/bookstack:latest`
3. `./start.sh` — the container runs migrations automatically on startup

### Useful settings pages

| Path | Description |
|---|---|
| `/settings` | General settings, name, logo |
| `/settings/users` | User management |
| `/settings/roles` | Role & permission management |
| `/settings/maintenance` | Cache clear, search rebuild, recycle bin |
| `/settings/audit` | Audit log |

---

## Debugging

### App not loading

```bash
docker logs bookstack --tail 50
docker logs bookstack_db --tail 20
```

### Database connection errors

```bash
docker exec bookstack_db mysqladmin ping -h localhost
```

### APP_KEY mismatch (sessions broken after re-install)

If you see "The MAC is invalid" errors, the `APP_KEY` in `.env` does not match the one the app was started with. Restore the original key or wipe and reinstall.

### Clear all caches

```bash
docker exec bookstack php /app/www/artisan cache:clear
docker exec bookstack php /app/www/artisan view:clear
docker exec bookstack php /app/www/artisan config:clear
```
