# Outline — Collaborative Knowledge Base

Outline is a fast, open-source wiki and knowledge base for teams. It features real-time collaborative editing, a clean Markdown interface, nested documents, full-text search, and role-based permissions.

- **Home page:** https://www.getoutline.com
- **Docs:** https://docs.getoutline.com/s/hosting
- **GitHub:** https://github.com/outline/outline
- **Docker image:** https://hub.docker.com/r/outlinewiki/outline

---

## Attribution

**Outline** is open-source software developed and maintained by General Outline Inc. and contributors. The server-side code is made freely available under the [BSL 1.1 License](https://github.com/outline/outline/blob/main/LICENSE); client-side code is MIT-licensed.

- **Support Outline:** [Outline Cloud](https://www.getoutline.com/pricing) (the managed SaaS offering)

---

## Local Access

| | |
|---|---|
| **URL** | http://localhost:3000 |
| **Auth** | OIDC via Keycloak (configure `OIDC_*` in `.env` once Keycloak is running) |
| **S3 storage** | Garage at http://localhost:3900, bucket `outline` |

> Outline has no built-in admin credentials. Access is granted through the configured auth provider. The first user to sign in becomes the workspace owner.

---

## Prerequisites

**Garage must be running** before starting Outline. `start.sh` reads S3 credentials from `infrastructure/garage/.env` automatically.

```bash
cd ../../infrastructure/garage && ./start.sh
```

**Keycloak** (coming soon under `infrastructure/keycloak`) will provide OIDC authentication. Until it is running, no one can sign in. Configure `OIDC_*` in `.env` and restart once Keycloak is available.

---

## Scripts

### `./start.sh`

On **first run**: copies `.env.example` → `.env`, generates `SECRET_KEY`, `UTILS_SECRET`, and `DB_PASSWORD`, auto-populates S3 credentials from Garage, starts all three containers (migrations run automatically inside the Outline container), and creates/configures the `outline` bucket in Garage.

Subsequent runs skip all generation steps and just start the stack.

```bash
./start.sh
```

### `./stop.sh`

Stops all containers. Data in `./data/` is preserved.

```bash
./stop.sh
```

### `./teardown.sh`

Interactive full teardown: lists what will be removed, prompts for confirmation, then deletes all containers, volumes, images, and networks.

```bash
./teardown.sh
```

To reinstall completely fresh (new secrets):

```bash
sed -i 's/^SECRET_KEY=.*/SECRET_KEY=OVERWRITE_ME/' .env
sed -i 's/^UTILS_SECRET=.*/UTILS_SECRET=OVERWRITE_ME/' .env
sed -i 's/^DB_PASSWORD=.*/DB_PASSWORD=OVERWRITE_ME/' .env
./teardown.sh
./start.sh
```

---

## Auth Setup

Outline requires at least one auth provider before any user can sign in.

### OIDC (Keycloak) — recommended

Once Keycloak is running, create an `outline` client in your realm and fill in `.env`:

```bash
# Browser-facing — use localhost so the browser can reach Keycloak
OIDC_AUTH_URI=http://localhost:8080/realms/<realm>/protocol/openid-connect/auth

# Server-to-server — Outline container reaches Keycloak via host.docker.internal
OIDC_TOKEN_URI=http://host.docker.internal:8080/realms/<realm>/protocol/openid-connect/token
OIDC_USERINFO_URI=http://host.docker.internal:8080/realms/<realm>/protocol/openid-connect/userinfo

OIDC_CLIENT_ID=outline
OIDC_CLIENT_SECRET=<client-secret-from-keycloak>
OIDC_DISPLAY_NAME=Keycloak
OIDC_USERNAME_CLAIM=preferred_username
```

Then restart: `./stop.sh && ./start.sh`

### SMTP magic-link — standalone fallback

Uncomment and fill in the `SMTP_*` section of `.env`. Outline will send magic-link emails for sign-in. Restart after changes.

---

## Files

| File | Purpose |
|---|---|
| `.env` | All runtime config — secrets, S3 credentials, auth, URLs |
| `docker-compose.yml` | 3-container stack definition |
| `data/postgres/` | PostgreSQL data directory |
| `data/redis/` | Redis persistence |
| `start.sh` | Start / first-run setup |
| `stop.sh` | Stop (data preserved) |
| `teardown.sh` | Full wipe with confirmation |

### `.env` — values of interest

| Variable | Value | Notes |
|---|---|---|
| `URL` | `http://localhost:3000` | Must match the browser URL |
| `SECRET_KEY` | *(generated)* | Encrypts cookies/sessions; **never change** after first start |
| `UTILS_SECRET` | *(generated)* | Used for utility functions; **never change** after first start |
| `DB_PASSWORD` | *(generated)* | PostgreSQL password |
| `AWS_ACCESS_KEY_ID` | *(from Garage)* | Auto-populated from `infrastructure/garage/.env` |
| `AWS_S3_UPLOAD_BUCKET_URL` | `http://host.docker.internal:3900` | Change to LAN IP for remote browser access |

---

## Architecture

```
Browser
  └─► localhost:3000
        └─► outline  (Outline app — Node.js)
              ├─► outline_db:5432   (PostgreSQL 17 — documents, users)
              ├─► outline_redis:6379 (Redis 7 — cache, collab sessions)
              └─► host.docker.internal:3900  (Garage S3 — file uploads)
                    └─► infrastructure/garage  (separate compose project)

OIDC sign-in flow:
  Browser ──► localhost:8080  (Keycloak — separate compose project, coming soon)
            ◄── redirect back to localhost:3000 with auth code
  outline ──► host.docker.internal:8080  (token + userinfo exchange)
```

**Containers:**

| Container | Image | Role |
|---|---|---|
| `outline` | `docker.getoutline.com/outlinewiki/outline` | App server |
| `outline_db` | `postgres:17` | Database |
| `outline_redis` | `redis:7-alpine` | Cache + real-time |

---

## Cheat Sheet

### Logs

```bash
# All services
docker compose -p outline logs -f

# App only
docker logs outline -f

# Database only
docker logs outline_db -f
```

### Shell access

```bash
docker exec -it outline sh
docker exec -it outline_db psql -U outline
```

### Check S3 bucket

```bash
# Verify the outline bucket exists and has the correct permissions
docker exec garage /garage bucket info outline
```

### Test S3 connectivity

```bash
export AWS_ACCESS_KEY_ID=$(grep ^AWS_ACCESS_KEY_ID .env | cut -d= -f2-)
export AWS_SECRET_ACCESS_KEY=$(grep ^AWS_SECRET_ACCESS_KEY .env | cut -d= -f2-)
aws --endpoint-url http://localhost:3900 s3 ls s3://outline/
```

### Database backup

```bash
docker exec outline_db pg_dump -U outline outline > outline_backup.sql
```

### Upgrade Outline

1. Update `OUTLINE_VERSION` in `.env` to the new tag
2. `./stop.sh`
3. `./start.sh` — pulls the new image; migrations run automatically on startup

---

## Debugging

### App not loading after first start

Allow 30–60 s for database migrations on first run:

```bash
docker logs outline --tail 50 -f
```

### S3 upload errors

Verify Garage is running and the bucket is configured:

```bash
docker exec garage /garage status
docker exec garage /garage bucket info outline
```

If the bucket is missing, re-run the allow command:

```bash
docker exec garage /garage bucket create outline 2>/dev/null || true
docker exec garage /garage bucket allow --read --write --owner outline --key default
```

### OIDC sign-in loop / token errors

Check that `OIDC_TOKEN_URI` and `OIDC_USERINFO_URI` use `host.docker.internal` (not `localhost`) so the Outline container can reach Keycloak. `OIDC_AUTH_URI` should use `localhost` (browser-facing).

### SECRET_KEY mismatch (sessions broken after re-install)

If users see session errors, the `SECRET_KEY` in `.env` does not match the one the app was started with. Restore the original key or wipe and reinstall.
