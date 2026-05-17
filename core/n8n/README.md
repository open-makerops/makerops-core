# n8n — Workflow Automation

n8n is an open-source workflow automation platform with a visual node-based editor. It connects APIs, databases, files, and services without writing code, and supports complex branching logic, error handling, sub-workflows, and hundreds of built-in integrations.

- **Home page:** https://n8n.io
- **Docs:** https://docs.n8n.io
- **GitHub:** https://github.com/n8n-io/n8n
- **Node library:** https://n8n.io/integrations
- **Docker Hub:** https://hub.docker.com/r/n8nio/n8n

---

## Attribution

**n8n** is open-source software developed and maintained by n8n GmbH (Berlin). It is made available under the [Sustainable Use License](https://github.com/n8n-io/n8n/blob/master/LICENSE.md) (a fair-code license — free for internal use, requires a commercial license for offering n8n as a service to others). The project is backed by venture capital and sustained through its cloud and enterprise offerings.

- **Cloud service:** [app.n8n.cloud](https://app.n8n.cloud) — n8n offers a fully managed cloud version with a free trial and paid plans. The cloud version handles infrastructure, scaling, and updates, and includes additional features like enhanced execution history and managed credentials.
- **Enterprise edition:** [n8n.io/enterprise](https://n8n.io/enterprise) — adds SSO, advanced RBAC, external secret stores, and dedicated support
- **Support & community:** [community.n8n.io](https://community.n8n.io) — active community forum for workflows, integrations, and troubleshooting

You do not need to run this service locally. n8n Cloud is the easiest path to get started and directly supports the development team.

---

## Local Access

| | |
|---|---|
| **URL** | http://localhost:5678 |
| **Credentials** | Created on first visit — n8n prompts you to set up an owner account |

n8n does not use pre-seeded credentials. The first person to access the UI sets the owner email and password through the setup wizard.

---

## Scripts

### `./start.sh`

On **first run** generates `N8N_ENCRYPTION_KEY` and `RUNNERS_AUTH_TOKEN` and writes them into `.env`, then pulls images and starts all 6 containers. Subsequent runs skip secret generation.

```bash
./start.sh
```

n8n is ready in ~30 seconds. Watch startup:
```bash
docker compose -p n8n logs -f n8n
```

### `./stop.sh`

Stops all containers. Volumes (workflows, credentials, execution history) are preserved.

```bash
./stop.sh
```

### `./teardown.sh`

Interactive full teardown — lists what will be removed, prompts for confirmation, then deletes everything.

```bash
./teardown.sh
```

> **Warning:** Tearing down deletes all workflows, credentials, and execution history. Export your workflows first (see [Back up workflows](#back-up-workflows)).

---

## Files

| File | Purpose |
|---|---|
| `.env` | All configuration and secrets |
| `docker-compose.yml` | 6-container stack (queue mode with task runners) |
| `init-data.sh` | Runs once at PostgreSQL first start to create the non-root app user |
| `start.sh` | Start / first-run setup |
| `stop.sh` | Stop (volumes preserved) |
| `teardown.sh` | Full wipe with confirmation |

### `.env` — values of interest

| Variable | Value | Notes |
|---|---|---|
| `N8N_VERSION` | `stable` | Image tag; pin to a version (e.g. `1.85.0`) for reproducibility |
| `N8N_PORT_HOST` | `5678` | Host port |
| `N8N_ENCRYPTION_KEY` | *(generated)* | Encrypts all stored credentials — **never change** after first start or all saved credentials become unreadable |
| `RUNNERS_AUTH_TOKEN` | *(generated)* | Shared secret between n8n and its external task runner sidecars |
| `WEBHOOK_URL` | `http://localhost:5678/` | The public URL n8n uses in webhook trigger URLs — must match how external services reach this instance |
| `GENERIC_TIMEZONE` | `America/Chicago` | Used by Schedule Trigger nodes — must match your local timezone |
| `N8N_LOG_LEVEL` | `info` | Options: `error`, `warn`, `info`, `verbose`, `debug` |
| `EXECUTIONS_DATA_MAX_AGE` | `336` (14 days) | Hours to keep execution records before pruning |
| `EXECUTIONS_DATA_PRUNE_MAX_COUNT` | `50000` | Maximum execution records to keep |
| `POSTGRES_NON_ROOT_USER` | `n8n_user` | The DB user n8n connects as at runtime |
| `POSTGRES_NON_ROOT_PASSWORD` | `n8n_user_pass` | Its password |

---

## Architecture

This stack runs n8n in **queue mode** — workflow executions are offloaded to a dedicated worker, keeping the main instance responsive for the UI, webhooks, and scheduling.

```
Browser / Webhooks
  └─► localhost:5678
        └─► n8n  (main instance — UI, API, webhook ingestion, scheduler)
              ├─► n8n-runner     (external task runner sidecar for JS sandboxing)
              ├─► n8n-worker     (pulls execution jobs from Redis queue)
              │     └─► n8n-worker-runner  (task runner sidecar for the worker)
              ├─► n8n_postgres:5432  (PostgreSQL 17 — workflow & credential store)
              └─► n8n_redis:6379     (Redis 6 — BullMQ job queue)
```

**Containers:**

| Container | Image | Role |
|---|---|---|
| `n8n_postgres` | `postgres:17` | Persistent data store (workflows, credentials, executions) |
| `n8n_redis` | `redis:6-alpine` | BullMQ job queue |
| `n8n` | `docker.n8n.io/n8nio/n8n:stable` | Main instance (UI + API + webhooks + scheduler) |
| `n8n_runner` | `n8nio/runners:stable` | JS task runner sidecar for main instance |
| `n8n_worker` | `docker.n8n.io/n8nio/n8n:stable` | Execution worker |
| `n8n_worker_runner` | `n8nio/runners:stable` | JS task runner sidecar for worker |

**Volumes:**

| Volume | Contents |
|---|---|
| `db_storage` | PostgreSQL data |
| `redis_storage` | Redis persistence |
| `n8n_storage` | n8n config and internal state (`~/.n8n`) |

---

## Cheat Sheet

### Logs

```bash
# All services
docker compose -p n8n logs -f

# Main n8n instance (UI, webhooks, scheduler)
docker logs n8n -f

# Worker (execution logs)
docker logs n8n_worker -f

# Task runner
docker logs n8n_runner -f
```

### Shell access

```bash
docker exec -it n8n sh
docker exec -it n8n_postgres psql -U n8n_user -d n8n
```

### Back up workflows

Export all workflows and credentials via the n8n CLI:

```bash
# Export all workflows to a JSON file
docker exec n8n n8n export:workflow --all --output=/home/node/.n8n/workflows.json
docker cp n8n:/home/node/.n8n/workflows.json ./workflows_backup.json

# Export all credentials (encrypted)
docker exec n8n n8n export:credentials --all --output=/home/node/.n8n/credentials.json
docker cp n8n:/home/node/.n8n/credentials.json ./credentials_backup.json
```

Or use the UI: **Settings → Import/Export**

### Restore workflows

```bash
docker cp ./workflows_backup.json n8n:/home/node/.n8n/workflows.json
docker exec n8n n8n import:workflow --input=/home/node/.n8n/workflows.json
```

### Import a workflow from a file

```bash
docker cp my_workflow.json n8n:/tmp/
docker exec n8n n8n import:workflow --input=/tmp/my_workflow.json
```

### Upgrade n8n

1. Update `N8N_VERSION` in `.env` to the target version (e.g. `1.85.0`)
2. `./stop.sh && ./start.sh`
3. n8n runs database migrations automatically on startup

> **Note:** Keep the `N8N_ENCRYPTION_KEY` intact across upgrades — it's needed to decrypt stored credentials.

### Clear stuck executions

```bash
# Remove all 'running' executions left over from a crash
docker exec n8n n8n executionFlushStuck
```

### Reset owner password (if locked out)

n8n 1.x does not have a CLI password reset. Options:

1. Use the "Forgot password" flow (requires SMTP to be configured)
2. Update directly in the database:

```bash
docker exec -it n8n_postgres psql -U n8n_user -d n8n \
  -c "UPDATE \"user\" SET password=NULL WHERE role='global:owner';"
```

Then reload the n8n UI — it will prompt you to set a new password.

---

## Debugging

### Workflow execution fails silently

- Check the execution log in the UI (click the execution in the left panel)
- Check the worker logs: `docker logs n8n_worker -f`

### Webhook trigger URL not working externally

`WEBHOOK_URL` in `.env` must match the URL external services use to reach n8n. For local-only use `http://localhost:5678/` is correct. For external access (tunnel, VPN), update `WEBHOOK_URL` to the public address and restart.

### Credentials showing as invalid after restart

The `N8N_ENCRYPTION_KEY` changed. Restore the original key from `.env` backup, or re-enter credentials manually.

### Redis queue not draining (worker idle)

```bash
docker logs n8n_worker --tail 30
docker logs n8n_redis --tail 10
```

If the worker is connected but idle, check that the workflow execution mode is `queue` in the n8n settings.

### Check execution data volume

```bash
docker exec n8n_postgres psql -U n8n_user -d n8n \
  -c "SELECT status, COUNT(*) FROM execution_entity GROUP BY status;"
```
