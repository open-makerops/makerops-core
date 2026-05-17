# Manufacturing Tools Stack

A collection of self-hosted, open-source services for manufacturing operations, deployed locally via Docker Compose. Each service runs as an independent, fully isolated Docker Compose project.

## Services

Idle RAM and base storage are measured with all services running and only an initial admin account created — no workflows, inventory, or projects added.

| Service | Port | Purpose | Idle RAM | Base Storage |
| ------- | ---- | ------- | -------- | ------------ |
| [n8n](https://n8n.io) | [5678](http://localhost:5678) | Workflow automation — integrates all services | ~470 MB | ~70 MB |
| [BookStack](https://www.bookstackapp.com) | [6875](http://localhost:6875) | Documentation and knowledge base | ~240 MB | ~165 MB |
| [FreeScout](https://freescout.net) | [8095](http://localhost:8095) | Help desk and shared inbox | ~330 MB | ~175 MB |
| [Invoice Ninja](https://invoiceninja.com) | [8092](http://localhost:8092) | Accounting and invoicing | ~1.1 GB | ~470 MB |
| [InvenTree](https://inventree.org) | [8096](http://localhost:8096) | Inventory and parts management | ~1.95 GB | ~140 MB |
| [Plane](https://plane.so) | [8100](http://localhost:8100) | Project management and work tracking | ~1.85 GB | ~80 MB |
| [trigger.dev](https://trigger.dev) | [3040](http://localhost:3040) | Background jobs and workflow execution | ~715 MB | ~75 MB |
| **Total** | | | **~6.7 GB** | **~1.2 GB** |

Supporting infrastructure for remote access to this host (WireGuard VPN, Cloudflare DDNS, SSH key setup) is documented in [remote_access/README.md](remote_access/README.md).

AI services for local LLM inference and agent workflows are documented in [ai/README.md](ai/README.md). These services run open-weight language models (Llama, Mistral, Gemma, and others) entirely on-premise — no API keys, no data leaving the host, no per-token costs. They integrate directly with n8n for automated AI workflows and are intended to complement the core stack rather than run alongside it at all times. **GPU required:** the NVIDIA Container Toolkit must be installed on the host before running any AI service.

## Total System Requirements

### Resource summary

| Resource | Value |
| -------- | ----- |
| Idle RAM | ~6.7 GB |
| Base volume storage | ~1.2 GB |
| Container images (disk) | ~17 GB |

### Minimum and recommended host resources

| Resource | Minimum | Recommended |
| -------- | ------- | ----------- |
| RAM | 8 GB | 16 GB |
| Disk | 25 GB SSD | 50 GB SSD |
| CPU | 2 cores | 4 cores |

**RAM**: The stack uses ~6.7 GB at idle. An 8 GB host leaves ~1.3 GB for the OS — workable but tight under active use. 16 GB provides comfortable headroom for concurrent users, background job execution, and memory spikes during file uploads or heavy queries.

The largest single consumer is InvenTree at ~1.95 GB. Its background worker (`qcluster`) forks multiple Python processes that each load the full Django application into memory; this is expected behavior and reflects the idle baseline, not a memory leak.

**Disk**: Container images (~17 GB) are a one-time pull per version and do not grow during operation. Volume storage starts at ~1.2 GB with no user data and grows as the stack is used.

### Volume storage growth

| Service | Primary growth drivers |
| ------- | ---------------------- |
| n8n | Workflow execution logs — prune via Settings → Log Pruning or set `EXECUTIONS_DATA_MAX_AGE` in `.env` |
| BookStack | Page content, file attachments, and image uploads |
| FreeScout | Email history and file attachments |
| Invoice Ninja | Invoice PDFs and documents; base includes ~245 MB of static app assets that don't change |
| InvenTree | Parts database, parts images, and document attachments — scales with inventory size |
| Plane | Project data and file uploads — scales with team and issue volume |
| trigger.dev | Job run history — prune via the dashboard or `npx trigger.dev runs delete` |

For storage sizing guidance by database engine:

- [PostgreSQL disk usage](https://www.postgresql.org/docs/current/diskusage.html) — used by n8n, InvenTree, Plane, trigger.dev
- [MySQL / MariaDB table sizing](https://mariadb.com/kb/en/optimizing-table_size/) — used by BookStack, FreeScout, Invoice Ninja

## Service Environment Files

Each service is configured via a `.env` file in its directory. These files hold service-specific secrets and settings — database passwords, API keys, encryption keys, port numbers, and initial admin credentials.

`.env` files are **git-ignored** and will never be committed. On first start, each service auto-generates secure random values for secrets and writes them to its `.env`, so the stack runs out of the box without manual configuration. **Review and update credentials before running in a production or externally-accessible environment.**

| Service | Config file | Key variables |
| ------- | ----------- | ------------- |
| BookStack | `core/bookstack/.env` | `DB_PASSWORD`, `MYSQL_ROOT_PASSWORD` |
| n8n | `core/n8n/.env` | `POSTGRES_PASSWORD`, `POSTGRES_NON_ROOT_PASSWORD` |
| FreeScout | `core/freescout/.env` | `DB_PASSWORD`, `ADMIN_EMAIL`, `ADMIN_PASS` |
| Invoice Ninja | `core/invoiceninja/.env` | `DB_PASSWORD`, `DB_ROOT_PASSWORD`, `IN_USER_EMAIL`, `IN_PASSWORD` |
| InvenTree | `core/inventree/.env` | `INVENTREE_DB_PASSWORD`, `INVENTREE_ADMIN_PASSWORD` |
| Plane | `core/plane/.env` | `POSTGRES_PASSWORD`, `SECRET_KEY`, `RABBITMQ_PASSWORD` |
| trigger.dev | `core/triggerdev/.env` | `POSTGRES_PASSWORD`, `ENCRYPTION_KEY`, `MAGIC_LINK_SECRET`, `SESSION_SECRET` |

An optional gist-based utility for syncing `.env` files between machines is described in [Environment File Management](#environment-file-management-optional) below.

---

## Environment File Management (Optional)

`push_envs.sh` and `pull_envs.sh` let you securely back up and restore all service `.env` files via a private GitHub Gist. Files are encrypted with [age](https://github.com/FiloSottile/age) using your SSH `ed25519` key before they leave the machine — the gist stores only ciphertext.

This is useful for bootstrapping the stack on a new machine from a fully-configured one, or as a secure off-machine backup of your secrets.

### Requirements

- **SSH `ed25519` key** registered with GitHub — see [remote_access/README.md → SSH Keys](remote_access/README.md#ssh-keys). Setting up SSH for GitHub is a general security practice independent of this flow.
- **`age` encryption tool** — see the [age installation guide](https://github.com/FiloSottile/age?tab=readme-ov-file#installation). Packages are available for all major systems (`apt install age`, `brew install age`, etc.).

### Gist setup (one time)

These steps are specific to this flow and not covered elsewhere:

1. Create a new **secret** gist at <https://gist.github.com>. Initial content does not matter — the scripts populate it.
2. On the gist page, open the dropdown next to the **Clone** button and select **Clone via SSH**. Copy the URL — it looks like `git@gist.github.com:<hash>.git`. The HTTPS URL will not work because the scripts authenticate with your key.
3. Run `./push_envs.sh` or `./pull_envs.sh`. You will be prompted for this URL once; it is saved to `.envs-gist.conf` for all subsequent runs.

### Usage

```bash
# Encrypt all local .env files and push to the gist
./push_envs.sh

# Pull the latest from the gist and decrypt into each service directory
./pull_envs.sh
```

Both scripts auto-discover service directories across the `core/`, `remote_access/`, and `ai/` concern areas. `push_envs.sh` encrypts every service directory that contains a `.env`; `pull_envs.sh` decrypts every matching file from the gist back into the appropriate service directory. Existing local `.env` files are overwritten on pull. The gist uses a flat file structure with one file per service: `<concern>.<service>.env.age` (e.g. `core.bookstack.env.age`).

---

## Prerequisites

- [Docker Engine 24+](https://docs.docker.com/engine/install/)
- [Docker Compose v2.20+](https://docs.docker.com/compose/install/)
- `openssl` — for automatic secret generation on first start

## Quick Start

```bash
# Start all core services
./core/start-all.sh

# Stop all core services
./core/stop-all.sh
```

Individual service control:

```bash
cd core/bookstack && ./start.sh
cd core/bookstack && ./stop.sh

cd core/n8n && ./start.sh
cd core/n8n && ./stop.sh

cd core/freescout && ./start.sh
cd core/freescout && ./stop.sh

cd core/invoiceninja && ./start.sh
cd core/invoiceninja && ./stop.sh

cd core/inventree && ./start.sh
cd core/inventree && ./stop.sh

cd core/plane && ./start.sh
cd core/plane && ./stop.sh

cd core/triggerdev && ./start.sh
cd core/triggerdev && ./stop.sh
```

## First Run Notes

### BookStack

- `APP_KEY` is auto-generated and saved to `core/bookstack/.env` on first start
- Default login: `admin@admin.com` / `password` — change immediately

### n8n

- `N8N_ENCRYPTION_KEY` and `RUNNERS_AUTH_TOKEN` are auto-generated and saved to `core/n8n/.env` on first start
- Create your owner account on first visit to `http://localhost:5678`
- **Keep `core/n8n/.env` backed up** — losing `N8N_ENCRYPTION_KEY` means losing access to all stored credentials

### FreeScout

- Database schema and admin account are created automatically on first start (~2–5 minutes)
- Set `ADMIN_EMAIL` and `ADMIN_PASS` in `core/freescout/.env` before first run — these cannot be changed via `.env` after the database is initialised
- Default login: values of `ADMIN_EMAIL` / `ADMIN_PASS` in `core/freescout/.env`

### Invoice Ninja

- `APP_KEY`, `DB_PASSWORD`, `DB_ROOT_PASSWORD`, and `IN_PASSWORD` are auto-generated and saved to `core/invoiceninja/.env` on first start
- Set `IN_USER_EMAIL` in `core/invoiceninja/.env` before first run to set the admin email
- **Do not change `APP_KEY` after first run** — it encrypts stored credentials and tokens
- Default login: value of `IN_USER_EMAIL` / `IN_PASSWORD` in `core/invoiceninja/.env`

### InvenTree

- `INVENTREE_DB_PASSWORD` and `INVENTREE_ADMIN_PASSWORD` are auto-generated and saved to `core/inventree/.env` on first start
- `secret_key.txt` is auto-generated inside the data volume on first start — **back it up and never delete it**, as it encrypts stored credentials
- Database migrations run automatically on startup (`INVENTREE_AUTO_UPDATE=True`)
- Default login: `admin` / value of `INVENTREE_ADMIN_PASSWORD` in `core/inventree/.env`

### Plane

- `SECRET_KEY`, `LIVE_SERVER_SECRET_KEY`, `POSTGRES_PASSWORD`, `RABBITMQ_PASSWORD`, `AWS_ACCESS_KEY_ID`, and `AWS_SECRET_ACCESS_KEY` are auto-generated and saved to `core/plane/.env` on first start
- Create your workspace and owner account on first visit to `http://localhost:8100`
- **Do not change `SECRET_KEY` after first run** — it invalidates all active sessions

### trigger.dev

- `POSTGRES_PASSWORD`, `MAGIC_LINK_SECRET`, `SESSION_SECRET`, `ENCRYPTION_KEY`, `PROVIDER_SECRET`, and `COORDINATOR_SECRET` are auto-generated and saved to `core/triggerdev/.env` on first start
- Uses magic link authentication — on first visit enter your email, then retrieve the login link from `docker logs trigger_webapp`
- **Never change `ENCRYPTION_KEY`, `MAGIC_LINK_SECRET`, or `SESSION_SECRET` after first run** — changing these breaks stored data or logs out all users
- The `docker-provider` and `coordinator` containers mount `/var/run/docker.sock` to spawn task worker containers on demand

## Data Persistence

All service data is stored in Docker named volumes scoped to each project. Stopping services preserves all data.

To remove a service's data volumes (destructive — cannot be undone):

```bash
cd core/<service> && ./stop.sh --volumes
```

To remove all data across all core services:

```bash
./core/stop-all.sh --volumes
```

## Architecture Notes

Each service is a separate Docker Compose project with its own network, volumes, and container namespace. They share only the host network interface (via distinct ports) and have no cross-service Docker networking by default.

| Service | Docker project | Database |
| ------- | ------------- | -------- |
| BookStack | `bookstack` | MariaDB 11 |
| n8n | `n8n` | PostgreSQL 17 |
| FreeScout | `freescout` | MariaDB 11 |
| Invoice Ninja | `invoiceninja` | MySQL 8 |
| InvenTree | `inventree` | PostgreSQL 17 |
| Plane | `plane` | PostgreSQL 15 |
| trigger.dev | `triggerdev` | PostgreSQL 16 |
