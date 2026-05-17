# FreeScout — Help Desk & Shared Inbox

FreeScout is an open-source help desk and shared mailbox application — a self-hosted alternative to HelpScout or Zendesk. It supports shared email inboxes, customer conversation threads, canned replies, modules/plugins, and multi-user teams.

- **Home page:** https://freescout.net
- **Docs:** https://github.com/freescout-help-desk/freescout/wiki
- **GitHub:** https://github.com/freescout-help-desk/freescout
- **Docker image:** https://hub.docker.com/r/tiredofit/freescout

---

## Attribution

**FreeScout** is open-source software developed and maintained by the FreeScout team. It is made freely available under the [AGPL-3.0 License](https://github.com/freescout-help-desk/freescout/blob/master/LICENSE). The Docker image used here is maintained by [tiredofit](https://github.com/tiredofit), an independent contributor who packages FreeScout and many other applications as community Docker images.

- **Support FreeScout:** [GitHub Sponsors](https://github.com/sponsors/freescout-help-desk)
- **Purchase premium modules:** [freescout.net/modules](https://freescout.net/modules) — the project sustains itself in part through paid extension modules for features like Slack integration, AI replies, and advanced reporting

FreeScout does not offer an official cloud-hosted service. It is designed as a self-hosted alternative to commercial help desks like HelpScout and Zendesk. If you prefer a managed service with similar functionality, consider [HelpScout](https://www.helpscout.com) or [Zendesk](https://www.zendesk.com) as commercial alternatives.

---

## Local Access

| | |
|---|---|
| **URL** | http://localhost:8095 |
| **Username** | see `ADMIN_EMAIL` in `.env` (`admin@admin.com`) |
| **Password** | see `ADMIN_PASS` in `.env` (`changeme`) |

**Change the password immediately after first login.** The credentials in `.env` are the initial values and cannot be updated via `.env` after the database is first seeded.

---

## Scripts

### `./start.sh`

Pulls images and starts the stack. On **first run** the application automatically installs and seeds the database (~2–5 minutes). No secret generation is needed — passwords are set directly in `.env`.

```bash
./start.sh
```

Watch first-run progress:

```bash
docker compose -p freescout logs -f freescout
```

### `./stop.sh`

Stops all containers. Volumes are preserved.

```bash
./stop.sh
```

### `./teardown.sh`

Interactive full teardown with confirmation prompt — removes all containers, volumes, images, and networks.

```bash
./teardown.sh
```

---

## Files

| File | Purpose |
|---|---|
| `.env` | Database passwords, admin credentials, site URL, timezone |
| `docker-compose.yml` | 2-container stack definition |
| `start.sh` | Start / first-run setup |
| `stop.sh` | Stop (volumes preserved) |
| `teardown.sh` | Full wipe with confirmation |

### `.env` — values of interest

| Variable | Value | Notes |
|---|---|---|
| `ADMIN_EMAIL` | `admin@admin.com` | Admin login email — set before first start; ignored after DB is seeded |
| `ADMIN_PASS` | `changeme` | Admin password — set before first start; **change this** |
| `SITE_URL` | `http://localhost:8095` | Must match the browser URL; changing it after first start requires a DB update |
| `FREESCOUT_PORT` | `8095` | Host port |
| `DB_PASSWORD` | `freescout_db_pass` | MariaDB app user password |
| `MYSQL_ROOT_PASSWORD` | `freescout_root_pass` | MariaDB root password |
| `TZ` | `America/Chicago` | Timezone for app and cron jobs |

> **Note:** `ADMIN_EMAIL` and `ADMIN_PASS` are **only consumed on first startup**. After the account exists in the database, changes here have no effect — use the web UI to change credentials instead.

---

## Architecture

```
Browser
  └─► localhost:8095
        └─► freescout  (Nginx + PHP-FPM — tiredofit image)
              └─► freescout_db:3306  (MariaDB 11)
```

**Containers:**

| Container | Image | Role |
|---|---|---|
| `freescout` | `tiredofit/freescout:latest` | App server (Nginx + PHP-FPM + cron) |
| `freescout_db` | `mariadb:11` | Database |

**Volumes:**

| Volume | Contents |
|---|---|
| `freescout_app_data` | Application data, attachments, configuration |
| `freescout_app_logs` | Nginx and PHP-FPM logs |
| `freescout_db_data` | MariaDB data |

---

## Cheat Sheet

### Logs

```bash
# All services
docker compose -p freescout logs -f

# App container (includes cron, PHP, Nginx)
docker logs freescout -f

# Database
docker logs freescout_db -f
```

### Shell access

```bash
docker exec -it freescout bash
docker exec -it freescout_db bash
```

### Run artisan commands

FreeScout is a Laravel application. Run commands via:

```bash
docker exec freescout php /www/laravel/artisan <command>

# Examples:
docker exec freescout php /www/laravel/artisan freescout:fetch-emails
docker exec freescout php /www/laravel/artisan cache:clear
docker exec freescout php /www/laravel/artisan queue:restart
```

### Reset admin password

```bash
docker exec -it freescout php /www/laravel/artisan freescout:create-user \
  --email=admin@admin.com --password=newpassword --role=admin --firstName=Admin --lastName=User
```

Or use the Forgot Password link on the login page (requires outgoing mail to be configured).

### Change SITE_URL after first start

If you need to change the URL after the database is seeded:

```bash
docker exec -it freescout_db mysql -u freescout -pfreescout_db_pass freescout \
  -e "UPDATE settings SET value='http://newurl:8095' WHERE name='app.url';"
docker exec freescout php /www/laravel/artisan cache:clear
```

Then update `SITE_URL` in `.env` and restart.

### Back up data

```bash
# Database dump
docker exec freescout_db mysqldump -u freescout -pfreescout_db_pass freescout > freescout_backup.sql

# Attachments and uploads are in the app_data volume
docker run --rm -v freescout_app_data:/data -v $(pwd):/backup alpine \
  tar czf /backup/freescout_data.tar.gz /data
```

### Upgrade FreeScout

The `tiredofit/freescout:latest` image auto-updates when the container restarts (`ENABLE_AUTO_UPDATE=FALSE` is set to prevent this during normal operation). To upgrade:

```bash
./stop.sh
docker pull tiredofit/freescout:latest
./start.sh
```

---

## Debugging

### First-run taking too long

The initial database install can take 2–5 minutes. Watch:

```bash
docker logs freescout -f
```

Look for `Starting services...` and then the app health check passing.

### Email not being received

1. Check mailbox settings at **Settings → Mailboxes**
2. Verify IMAP/SMTP credentials are correct
3. Manually trigger a fetch: `docker exec freescout php /www/laravel/artisan freescout:fetch-emails`
4. Check logs for mail errors: `docker logs freescout | grep -i mail`

### "SITE_URL mismatch" errors

The app shows warnings if `SITE_URL` in `.env` doesn't match the database value. Update both and restart.

### Queue stuck / emails not sending

```bash
docker exec freescout php /www/laravel/artisan queue:restart
```
