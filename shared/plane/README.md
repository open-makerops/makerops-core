# Plane — Project Management

Plane is an open-source project management platform — a self-hosted alternative to Linear, Jira, and Asana. It supports issues, cycles (sprints), modules (epics), views, pages (wiki), and real-time collaboration.

- **Home page:** https://plane.so
- **Docs:** https://docs.plane.so
- **GitHub:** https://github.com/makeplane/plane
- **Releases:** https://github.com/makeplane/plane/releases

---

## Attribution

**Plane** is open-source software developed and maintained by Plane (makeplane). It is made available under the [AGPL-3.0 License](https://github.com/makeplane/plane/blob/master/LICENSE). The project is venture-backed and sustained through its cloud and Pro offerings.

- **Cloud service:** [app.plane.so](https://app.plane.so) — Plane offers a fully managed cloud version with a generous free tier and paid Pro/Business plans. The cloud version handles infrastructure, updates, and backups, and your subscription supports continued open-source development.
- **Plane Pro / Business:** Adds unlimited members, advanced analytics, custom workflows, priority support, and more — available on both cloud and self-hosted
- **Community:** [GitHub Discussions](https://github.com/makeplane/plane/discussions) · [Discord](https://discord.com/invite/A92xrEGCge)

You do not need to run this service locally. Plane Cloud includes a free tier suitable for small teams and is the lowest-friction way to get started.

---

## Local Access

| | |
|---|---|
| **URL** | http://localhost:8100 |
| **God Mode (instance admin)** | http://localhost:8100/god-mode/ |

**First-run setup:** On first visit, Plane redirects to a setup wizard where you create the instance administrator account. The instance admin can then configure the instance and create workspaces.

- **God Mode** is the instance administration panel (email settings, feature flags, AI config, SSO)
- **Spaces** (public embeddable issue views) are at http://localhost:8100/spaces/

---

## Scripts

### `./start.sh`

On **first run** generates all secrets (`SECRET_KEY`, `LIVE_SERVER_SECRET_KEY`, `POSTGRES_PASSWORD`, `RABBITMQ_PASSWORD`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`) and derives `DATABASE_URL` and `AMQP_URL` from the component values, writes everything into `.env`, then pulls images and starts the stack.

```bash
./start.sh
```

First-run startup takes ~60 seconds:

1. PostgreSQL, Valkey, RabbitMQ, and MinIO start and pass healthchecks
2. `create-bucket` initialises the MinIO uploads bucket (one-shot)
3. `migrator` runs Django database migrations (one-shot)
4. All application services start once migrations complete

Watch progress:

```bash
docker compose -p plane logs -f migrator
docker compose -p plane logs -f api
```

### `./stop.sh`

Stops all containers. Volumes are preserved.

```bash
./stop.sh
```

### `./teardown.sh`

Interactive full teardown — lists everything that will be removed, prompts for confirmation, then deletes all containers, volumes, images, and networks.

```bash
./teardown.sh
```

---

## Files

| File | Purpose |
|---|---|
| `.env` | All runtime configuration and secrets |
| `docker-compose.yml` | 13-container stack definition |
| `start.sh` | Start / first-run setup (secret generation + URL derivation) |
| `stop.sh` | Stop (volumes preserved) |
| `teardown.sh` | Full wipe with confirmation |

### `.env` — values of interest

| Variable | Value | Notes |
|---|---|---|
| `APP_RELEASE` | `v1.3.0` | Image tag for all Plane services; update together |
| `LISTEN_HTTP_PORT` | `8100` | Host port |
| `WEB_URL` | `http://localhost:8100` | Must match the browser URL; used in emails and API responses |
| `SECRET_KEY` | *(generated)* | Django secret key — **never change** after first run; invalidates all sessions |
| `LIVE_SERVER_SECRET_KEY` | *(generated)* | Shared secret for the real-time collaboration server |
| `POSTGRES_PASSWORD` | *(generated)* | PostgreSQL password |
| `RABBITMQ_PASSWORD` | *(generated)* | RabbitMQ password |
| `AWS_ACCESS_KEY_ID` | *(generated)* | MinIO root credentials (S3-compatible object storage) |
| `AWS_SECRET_ACCESS_KEY` | *(generated)* | MinIO root credentials |
| `DATABASE_URL` | *(derived)* | Full PostgreSQL connection URL — derived from individual values by `start.sh` |
| `AMQP_URL` | *(derived)* | Full RabbitMQ AMQP URL — derived from individual values by `start.sh` |
| `GUNICORN_WORKERS` | `2` | API Gunicorn workers; formula is `2 × CPU cores + 1` for production |
| `FILE_SIZE_LIMIT` | `5242880` | Max upload size in bytes (5 MB default) |
| `DEBUG` | `0` | Set to `1` for Django debug mode (verbose errors, no email sending) |

---

## Architecture

Plane is a multi-tier application with 13 containers.

```
Browser
  └─► localhost:8100
        └─► plane_proxy  (makeplane/plane-proxy — routes by path)
              ├─► /  →  plane_web    (React frontend — Next.js)
              ├─► /api/  →  plane_api  (Django/Gunicorn)
              │              ├─► plane_db:5432     (PostgreSQL 15)
              │              ├─► plane_redis:6379  (Valkey 7.2 — cache + Celery results)
              │              └─► plane_mq:5672     (RabbitMQ 3.13 — Celery broker)
              ├─► /spaces/  →  plane_space   (public embeddable views)
              ├─► /god-mode/  →  plane_admin  (instance admin panel)
              └─► /live/   →  plane_live   (real-time collaboration — Node.js)

plane_worker      — Celery worker (background jobs: notifications, exports)
plane_beat_worker — Celery beat (scheduled tasks)
plane_minio       — MinIO (file uploads, S3-compatible)
plane_migrator    — One-shot Django migration runner (exits after success)
plane_create_bucket — One-shot MinIO bucket initialisation (exits after success)
```

**Containers:**

| Container | Image | Role |
|---|---|---|
| `plane_db` | `postgres:15.7-alpine` | Application database |
| `plane_redis` | `valkey/valkey:7.2.11-alpine` | Cache and Celery results backend |
| `plane_mq` | `rabbitmq:3.13.6-management-alpine` | Celery message broker |
| `plane_minio` | `minio/minio:latest` | Object storage (file uploads) |
| `plane_migrator` | `makeplane/plane-backend:v1.3.0` | One-shot migration runner |
| `plane_create_bucket` | `minio/mc:latest` | One-shot MinIO bucket creation |
| `plane_api` | `makeplane/plane-backend:v1.3.0` | Django/Gunicorn API |
| `plane_worker` | `makeplane/plane-backend:v1.3.0` | Celery worker |
| `plane_beat_worker` | `makeplane/plane-backend:v1.3.0` | Celery beat scheduler |
| `plane_web` | `makeplane/plane-frontend:v1.3.0` | Next.js web frontend |
| `plane_space` | `makeplane/plane-space:v1.3.0` | Public spaces frontend |
| `plane_admin` | `makeplane/plane-admin:v1.3.0` | God Mode admin panel |
| `plane_live` | `makeplane/plane-live:v1.3.0` | Real-time collaboration (Node.js) |
| `plane_proxy` | `makeplane/plane-proxy:v1.3.0` | Reverse proxy (routes all traffic) |

**Volumes:**

| Volume | Contents |
|---|---|
| `pgdata` | PostgreSQL data |
| `redisdata` | Valkey persistence |
| `rabbitmq_data` | RabbitMQ messages and state |
| `uploads` | MinIO object storage (file attachments) |
| `logs_api` | API container logs |
| `logs_worker` | Worker container logs |
| `logs_beat_worker` | Beat worker logs |
| `logs_migrator` | Migrator run logs |

---

## Cheat Sheet

### Logs

```bash
# All services
docker compose -p plane logs -f

# API backend
docker logs plane_api -f

# Celery worker
docker logs plane_worker -f

# Frontend
docker logs plane_web -f

# Migration output (one-shot, check after startup)
docker logs plane_migrator

# RabbitMQ management UI (no host port — use exec)
docker exec plane_mq rabbitmqctl list_queues
```

### Shell access

```bash
# API shell (Django)
docker exec -it plane_api bash

# Database
docker exec -it plane_db psql -U plane -d plane

# MinIO client
docker exec -it plane_minio sh
```

### Django management commands

```bash
docker exec plane_api python manage.py <command>

# Examples:
docker exec plane_api python manage.py shell
docker exec plane_api python manage.py create_bucket          # recreate MinIO bucket
docker exec plane_api python manage.py migrate                 # run pending migrations
```

### Back up data

```bash
# Database dump
PG_PASS=$(grep '^POSTGRES_PASSWORD=' .env | cut -d= -f2-)
docker exec plane_db pg_dump -U plane plane | gzip > plane_backup.sql.gz

# File uploads (MinIO)
docker run --rm -v uploads:/data -v $(pwd):/backup alpine \
  tar czf /backup/plane_uploads.tar.gz /data
```

### Upgrade Plane

1. Update `APP_RELEASE` in `.env` to the new version (e.g. `v1.4.0`)
2. `./stop.sh && ./start.sh`
3. The `migrator` container runs Django migrations automatically on startup

> **Important:** Do not skip versions. Check the [release notes](https://github.com/makeplane/plane/releases) for any breaking changes or manual migration steps.

### View RabbitMQ queues (management plugin)

The `rabbitmq:management` image includes a web UI on port 15672, but it is not exposed to the host. Use exec instead:

```bash
docker exec plane_mq rabbitmqctl list_queues name messages consumers
docker exec plane_mq rabbitmqctl list_channels
```

### Adjust file upload size limit

Edit `FILE_SIZE_LIMIT` in `.env` (value is in bytes):

```
FILE_SIZE_LIMIT=20971520   # 20 MB
```

Then restart the stack.

---

## Debugging

### Migrator fails on first run

```bash
docker logs plane_migrator
```

Common causes:

- PostgreSQL not yet healthy (wait and retry: `docker compose -p plane up -d migrator`)
- Database connection string wrong in `DATABASE_URL`

### API returning 500 errors

```bash
docker logs plane_api --tail 50
```

Set `DEBUG=1` in `.env` and restart the `api` service for Django's verbose error pages.

### File uploads not working

```bash
docker logs plane_minio --tail 20
docker exec plane_minio mc ls myminio/uploads   # check bucket exists
```

If the bucket is missing, re-run:

```bash
docker compose -p plane up create-bucket
```

### Real-time collaboration not working (live cursor, comments)

```bash
docker logs plane_live --tail 20
```

The live server connects to the API at `http://api:8000` (internal Docker network). If the API is unhealthy, the live server will fail to authenticate.

### God Mode shows "instance not configured"

Navigate to http://localhost:8100/god-mode/ and complete the instance setup. You need to:

1. Set the instance admin email and name
2. (Optional) Configure SMTP for email invitations
