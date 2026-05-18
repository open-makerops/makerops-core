# trigger.dev — Background Jobs & Workflow Automation

trigger.dev is an open-source platform for building and running reliable background jobs, scheduled tasks, and long-running workflows. Developers define tasks in code using the trigger.dev SDK; the platform handles queuing, retries, concurrency control, real-time observability, and execution infrastructure.

- **Home page:** https://trigger.dev
- **Docs:** https://trigger.dev/docs
- **GitHub:** https://github.com/triggerdotdev/trigger.dev
- **Docker repo:** https://github.com/triggerdotdev/docker
- **SDK quickstart:** https://trigger.dev/docs/quick-start

---

## Attribution

**trigger.dev** is open-source software developed and maintained by Trigger.dev (YC W23). It is made available under the [AGPL-3.0 License](https://github.com/triggerdotdev/trigger.dev/blob/main/LICENSE). The project is venture-backed and sustained through its cloud offerings.

- **Cloud service:** [trigger.dev](https://trigger.dev) — Trigger.dev offers a fully managed cloud platform with a Hobby tier (free), Team, and Enterprise plans. The cloud version handles worker infrastructure, scaling, execution history, and alerting, and your subscription directly supports the development team.
- **Self-hosted vs. cloud trade-off:** Running self-hosted means managing the Docker provider and coordinator, which spawn and clean up ephemeral worker containers on the host machine — adding meaningful operational complexity compared to the cloud offering.
- **Community & support:** [trigger.dev/discord](https://trigger.dev/discord) · [GitHub Discussions](https://github.com/triggerdotdev/trigger.dev/discussions)

You do not need to run this service locally. The Trigger.dev cloud Hobby tier covers most development and small-scale production workloads at no cost.

---

## Local Access

| | |
|---|---|
| **URL** | http://localhost:3040 |
| **Authentication** | Magic link — see [First-run setup](#first-run-setup) |

trigger.dev uses passwordless magic link authentication by default. On first visit, enter an email address and retrieve the login link from the webapp container logs (or configure Resend/SMTP to have it delivered by email).

---

## First-run Setup

1. Run `./start.sh` and wait ~30 seconds for the webapp to become ready
2. Open http://localhost:3040 and enter your email address, then click **Send magic link**
3. Retrieve the magic link from the webapp logs:
   ```bash
   docker compose -p triggerdev logs webapp 2>&1 | grep 'http://' | tail -5
   ```
   Look for a line containing the full login URL:

   ```text
   http://localhost:3040/magic?token=U2FsdGVkX1...%2Bos
   ```

   The token is a long URL-encoded encrypted string. Copy the **entire URL** and open it in your browser.

   > **Common mistake:** the webapp also logs a short `requestId` (e.g. `_IpF0NyOG2ux6eORKCFGZ`) as part of
   > the HTTP access log. That is a request trace ID, not the magic link token — do not use it.
   > The magic link token is ~100+ characters and only appears on the `http://localhost:3040/magic?token=…` line.

   > **No output?** The link is emitted at the moment you submit your email, not at startup. If nothing
   > appears, re-submit the form and run the command again immediately after.

4. Open the full URL in your browser to complete sign-in and create your account
5. Create an organisation and project from the dashboard

To restrict who can sign up, set `WHITELISTED_EMAILS` in `.env` before first start (see [.env values of interest](#env--values-of-interest)).

---

## Scripts

### `./start.sh`
On **first run** generates all secrets (`POSTGRES_PASSWORD`, `MAGIC_LINK_SECRET`, `SESSION_SECRET`, `ENCRYPTION_KEY`, `PROVIDER_SECRET`, `COORDINATOR_SECRET`) and derives `DATABASE_URL` and `DIRECT_URL` from component values, writes everything into `.env`, then pulls images and starts the stack.

```bash
./start.sh
```

### `./stop.sh`
Stops all containers. Volumes (database, Redis) are preserved.

```bash
./stop.sh
```

### `./teardown.sh`
Interactive full teardown — lists everything that will be removed, prompts for confirmation, then deletes all containers, volumes, images, and networks.

```bash
./teardown.sh
```

To re-install completely fresh (new secrets):
```bash
sed -i 's/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=GENERATE_ME/' .env
sed -i 's/^DATABASE_URL=.*/DATABASE_URL=GENERATE_ME/' .env
sed -i 's/^DIRECT_URL=.*/DIRECT_URL=GENERATE_ME/' .env
sed -i 's/^MAGIC_LINK_SECRET=.*/MAGIC_LINK_SECRET=GENERATE_ME/' .env
sed -i 's/^SESSION_SECRET=.*/SESSION_SECRET=GENERATE_ME/' .env
sed -i 's/^ENCRYPTION_KEY=.*/ENCRYPTION_KEY=GENERATE_ME/' .env
sed -i 's/^PROVIDER_SECRET=.*/PROVIDER_SECRET=GENERATE_ME/' .env
sed -i 's/^COORDINATOR_SECRET=.*/COORDINATOR_SECRET=GENERATE_ME/' .env
./teardown.sh
./start.sh
```

---

## Files

| File | Purpose |
|---|---|
| `.env` | All runtime configuration and secrets |
| `docker-compose.yml` | 6-container stack definition |
| `start.sh` | Start / first-run setup (secret generation + URL derivation) |
| `stop.sh` | Stop (volumes preserved) |
| `teardown.sh` | Full wipe with confirmation |

### `.env` — values of interest

| Variable | Value | Notes |
|---|---|---|
| `TRIGGER_IMAGE_TAG` | `v3` | Image tag for all trigger.dev services; update together when upgrading |
| `LISTEN_PORT` | `3040` | Host port |
| `TRIGGER_PROTOCOL` | `http` | `http` for local; `https` when behind a TLS-terminating proxy |
| `TRIGGER_DOMAIN` | `localhost:3040` | Must match the browser URL; used in magic links and OAuth callbacks |
| `POSTGRES_PASSWORD` | *(generated)* | PostgreSQL password |
| `DATABASE_URL` | *(derived)* | Full PostgreSQL connection URL — derived from component values by `start.sh` |
| `MAGIC_LINK_SECRET` | *(generated)* | Signs magic login links — **never change** after first run |
| `SESSION_SECRET` | *(generated)* | Signs session cookies — **never change** after first run (logs out all users) |
| `ENCRYPTION_KEY` | *(generated)* | Encrypts stored data — **never change** after first run (data becomes unreadable) |
| `PROVIDER_SECRET` | *(generated)* | Shared secret between webapp and docker-provider |
| `COORDINATOR_SECRET` | *(generated)* | Shared secret between webapp and coordinator |
| `DEFAULT_ENV_EXECUTION_CONCURRENCY_LIMIT` | `100` | Max concurrent task runs per environment |
| `DEFAULT_ORG_EXECUTION_CONCURRENCY_LIMIT` | `300` | Max concurrent task runs per organisation |
| `WHITELISTED_EMAILS` | *(unset)* | Regex to restrict signups — e.g. `you@example\.com\|team@example\.com` |
| `RESEND_API_KEY` | *(unset)* | Set to deliver magic links by email (via Resend); without it links appear in logs |
| `AUTH_GITHUB_CLIENT_ID` | *(unset)* | Optional GitHub OAuth login |

---

## Architecture

trigger.dev runs as 6 containers. The `docker-provider` and `coordinator` spawn ephemeral worker containers on demand by connecting to the host Docker daemon via `/var/run/docker.sock`.

```
Browser / SDK
  └─► localhost:3040
        └─► trigger_webapp  (trigger.dev webapp — UI + API + task queue)
              ├─► trigger_db:5432      (PostgreSQL 16 — task history, configs, runs)
              ├─► trigger_redis:6379   (Redis 7 — job queue, pub/sub)
              └─► trigger_electric:3000 (ElectricSQL — real-time sync layer)

trigger_provider  — Docker provider (spawns worker containers via Docker socket)
trigger_coordinator — Coordinator (manages checkpointing and worker lifecycle)
```

**Containers:**

| Container | Image | Role |
|---|---|---|
| `trigger_webapp` | `ghcr.io/triggerdotdev/trigger.dev:v3` | Webapp (UI + API + scheduler) |
| `trigger_db` | `postgres:16` | Application database |
| `trigger_redis` | `redis:7` | Job queue and pub/sub |
| `trigger_electric` | `electricsql/electric:latest` | Real-time PostgreSQL sync |
| `trigger_provider` | `ghcr.io/triggerdotdev/provider/docker:v3` | Docker task runner provider |
| `trigger_coordinator` | `ghcr.io/triggerdotdev/coordinator:v3` | Task checkpoint coordinator |

**Volumes:**

| Volume | Contents |
|---|---|
| `triggerdev_db_data` | PostgreSQL data |
| `triggerdev_redis_data` | Redis persistence |

> **Docker socket:** `trigger_provider` and `trigger_coordinator` both mount `/var/run/docker.sock` and run as `root`. They pull task images from a registry and spawn/stop worker containers on the host as tasks execute.

---

## Cheat Sheet

### Logs
```bash
# All services
docker compose -p triggerdev logs -f

# Webapp (UI, API, scheduler)
docker logs trigger_webapp -f

# Docker provider (worker spawning)
docker logs trigger_provider -f

# Coordinator
docker logs trigger_coordinator -f

# Database
docker logs trigger_db -f
```

### Shell access
```bash
# Webapp shell
docker exec -it trigger_webapp sh

# Database
docker exec -it trigger_db psql -U postgres -d trigger
```

### Get the magic link (first-run / locked out)
```bash
docker logs trigger_webapp 2>&1 | grep -i 'magic\|login' | tail -5
```

### SDK setup (connecting your app to this instance)
```bash
# Install the SDK in your project
npm install @trigger.dev/sdk

# Point the CLI at this instance
npx trigger.dev login --api-url http://localhost:3040

# Initialise a project
npx trigger.dev init
```

### Run a task manually (CLI)
```bash
npx trigger.dev run <task-id>
```

### Upgrade trigger.dev
1. Update `TRIGGER_IMAGE_TAG` in `.env` to the new version (e.g. `v3.x.y`)
2. `./stop.sh && ./start.sh`
3. Database migrations run automatically on webapp startup

> Check the [release notes](https://github.com/triggerdotdev/trigger.dev/releases) for breaking changes before upgrading.

### Adjust concurrency limits
Edit `.env`:
```
DEFAULT_ENV_EXECUTION_CONCURRENCY_LIMIT=200   # per environment
DEFAULT_ORG_EXECUTION_CONCURRENCY_LIMIT=600   # per organisation
```
Then restart: `./stop.sh && ./start.sh`

### Enable email delivery (magic links via email)
Set in `.env`:
```
FROM_EMAIL=noreply@yourdomain.com
REPLY_TO_EMAIL=support@yourdomain.com
RESEND_API_KEY=re_xxxxxxxxxxxx
```
Then restart: `./stop.sh && ./start.sh`

### Back up data
```bash
# Database dump
docker exec trigger_db pg_dump -U postgres trigger | gzip > triggerdev_backup.sql.gz
```

---

## Debugging

### Webapp not responding
```bash
docker logs trigger_webapp --tail 50
```
Check that PostgreSQL and Redis are healthy before the webapp starts.

### Magic link not appearing in logs
```bash
docker logs trigger_webapp 2>&1 | grep -i 'magic\|link\|login' | tail -10
```
If nothing appears, confirm the webapp started successfully first (`docker logs trigger_webapp | tail -20`). The link is emitted at the moment of the login request, not at startup.

### Tasks not executing (stuck in "Queued")
```bash
docker logs trigger_provider --tail 30
docker logs trigger_coordinator --tail 30
```
Common causes:
- `docker-provider` cannot connect to the Docker daemon — verify `/var/run/docker.sock` is accessible
- Worker image failed to pull — check provider logs for image pull errors
- `PLATFORM_SECRET` mismatch between webapp and provider/coordinator

### Provider / coordinator cannot connect to webapp
Both connect to `webapp:3030` on the internal Docker network. Verify the webapp container is healthy:
```bash
docker inspect trigger_webapp --format '{{.State.Health.Status}}'
```
If unhealthy, check webapp logs for startup errors (database connection, migration failures).

### ElectricSQL sync errors
```bash
docker logs trigger_electric --tail 20
```
Electric connects to PostgreSQL with `wal_level=logical` (set in the compose command). If it fails, verify PostgreSQL started with that WAL level:
```bash
docker exec trigger_db psql -U postgres -c "SHOW wal_level;"
```

### Database connection errors
```bash
docker exec trigger_db pg_isready -U postgres
```
If not ready, check:
```bash
docker logs trigger_db --tail 20
```

### Reset (locked out / corrupt state)
Export any task definitions from source control (they live in your application code, not in the database). Then teardown and reinstall:
```bash
./teardown.sh
./start.sh
```
