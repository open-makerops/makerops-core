# MakerOps Core

![MakerOps Core](assets/images/makerops-core-hero.png)

A collection of self-hosted, open-source and fair-use services for facilitating common business operations, deployed locally via Docker Compose. Each service runs as an independent*, fully isolated Docker Compose project.

## Key Considerations

> [!IMPORTANT]
> Review this section before deploying beyond initial local testing.

### Docker is a Hard Requirement

This stack runs entirely on [Docker](https://www.docker.com/) and Docker Compose. There is no alternative runtime — Docker must be installed on the host before any service can start.

Install Docker for your platform:

- [Docker Engine — Linux](https://docs.docker.com/engine/install/) — recommended for production hosts
- [Docker Desktop — macOS](https://docs.docker.com/desktop/install/mac-install/) — includes Compose, a GUI, and resource controls
- [Docker Desktop — Windows](https://docs.docker.com/desktop/install/windows-install/) — requires WSL 2 or Hyper-V

Additional resources:

- [Docker Compose overview](https://docs.docker.com/compose/)
- [Managing data in Docker (volumes, bind mounts)](https://docs.docker.com/storage/)
- [Container resource limits (CPU / memory)](https://docs.docker.com/engine/containers/resource_constraints/)
- [Docker Hub — image registry](https://hub.docker.com/)

### All Data is Written to the Host's Primary Drive by Default

> [!WARNING]
> Storing production data on a single drive with no redundancy is a significant risk. A drive failure means unrecoverable data loss.

Service data volumes write to the host's primary drive out of the box. This is fine for local testing and sandboxing. For any production or team use, treat storage as a first-class concern:

- **RAID** — [RAID levels explained (Prepressure)](https://www.prepressure.com/library/technology/raid) / [RAID Wikipedia](https://en.wikipedia.org/wiki/RAID) — RAID 1 mirrors data across two drives; RAID 5/6 adds parity for larger arrays
- **NAS / network storage** — [TrueNAS](https://www.truenas.com/) (open-source NAS OS) / [Synology](https://www.synology.com/en-global/solution/small_business) — attach network volumes to Docker as bind mounts
- **Off-site and cloud backup** — [Restic](https://restic.net/) (encrypted deduplicating backups) / [Backblaze B2](https://www.backblaze.com/cloud-storage) / [AWS S3 Glacier](https://aws.amazon.com/s3/glacier/)
- **Docker volume backup** — [Official backup and restore guide](https://docs.docker.com/engine/storage/volumes/#back-up-restore-or-migrate-data-volumes)

Each service exposes a data path variable in its `.env.example` so volumes can be redirected to a mounted drive or NAS share.

### Several Services Offer Paid Cloud Plans

Some services in this stack are also offered as vendor-managed SaaS products. The self-hosted versions included here are fully functional, but cloud plans provide managed infrastructure, automatic upgrades, enterprise SSO, compliance certifications, SLAs, and dedicated support — which may be preferable as teams grow.

| Service | Pricing page |
| ------- | ------------ |
| [n8n](https://n8n.io) — workflow automation | [n8n Cloud plans](https://n8n.io/pricing/) |
| [Outline](https://www.getoutline.com) — knowledge base | [Outline pricing](https://www.getoutline.com/pricing) |
| [Invoice Ninja](https://invoiceninja.com) — invoicing | [Invoice Ninja plans](https://invoiceninja.com/pricing/) |
| [Plane](https://plane.so) — project management | [Plane pricing](https://plane.so/pricing) |
| [trigger.dev](https://trigger.dev) — background jobs | [trigger.dev pricing](https://trigger.dev/pricing) |

---

Services are organized by labor area:

- [accounting/](accounting/README.md) — finance and billing staff
- [sales/](sales/README.md) — sales and customer service staff
- [operations/](operations/README.md) — operations and supply chain staff
- [shared/](shared/README.md) — cross-functional services used by all disciplines
- [infrastructure/](infrastructure/README.md) — backend primitives (object storage, etc.)

Supporting infrastructure for remote access to this host (WireGuard VPN, Cloudflare DDNS, SSH key setup) is documented in [remote_access/README.md](remote_access/README.md).

AI services for local LLM inference and agent workflows are documented in [ai/README.md](ai/README.md).

## Services

Idle RAM and base storage are measured with all services running and only an initial admin account created — no workflows, inventory, or projects added.

| Service | Port | Purpose | Idle RAM | Base Storage |
| ------- | ---- | ------- | -------- | ------------ |
| [n8n](https://n8n.io) | [5678](http://localhost:5678) | Workflow automation — integrates all services | ~470 MB | ~70 MB |
| [Outline](https://www.getoutline.com) | [3000](http://localhost:3000) | Collaborative knowledge base and wiki | ~350 MB | ~100 MB |
| [FreeScout](https://freescout.net) | [8095](http://localhost:8095) | Help desk and shared inbox | ~330 MB | ~175 MB |
| [Invoice Ninja](https://invoiceninja.com) | [8092](http://localhost:8092) | Accounting and invoicing | ~1.1 GB | ~470 MB |
| [InvenTree](https://inventree.org) | [8096](http://localhost:8096) | Inventory and parts management | ~1.95 GB | ~140 MB |
| [Plane](https://plane.so) | [8100](http://localhost:8100) | Project management and work tracking | ~1.85 GB | ~80 MB |
| [trigger.dev](https://trigger.dev) | [3040](http://localhost:3040) | Background jobs and workflow execution | ~715 MB | ~75 MB |
| [Garage](https://garagehq.deuxfleurs.fr) | [3900](http://localhost:3900) | S3-compatible object store (Outline backend) | ~30 MB | ~15 MB |
| **Total** | | | **~6.8 GB** | **~1.1 GB** |

## Total System Requirements

### Resource summary

| Resource | Value |
| -------- | ----- |
| Idle RAM | ~6.8 GB |
| Base volume storage | ~1.1 GB |
| Container images (disk) | ~17 GB |

### Minimum and recommended host resources

| Resource | Minimum | Recommended |
| -------- | ------- | ----------- |
| RAM | 8 GB | 16 GB |
| Disk | 25 GB SSD | 50 GB SSD |
| CPU | 2 cores | 4 cores |

**RAM**: The stack uses ~6.8 GB at idle. An 8 GB host leaves ~1.2 GB for the OS — workable but tight under active use. 16 GB provides comfortable headroom for concurrent users, background job execution, and memory spikes during file uploads or heavy queries.

The largest single consumer is InvenTree at ~1.95 GB. Its background worker (`qcluster`) forks multiple Python processes that each load the full Django application into memory; this is expected behavior and reflects the idle baseline, not a memory leak.

**Disk**: Container images (~17 GB) are a one-time pull per version and do not grow during operation. Volume storage starts at ~1.2 GB with no user data and grows as the stack is used. Configuration options are available per service to designate data storage location.

### Volume storage growth

| Service | Primary growth drivers |
| ------- | ---------------------- |
| n8n | Workflow execution logs — prune via Settings → Log Pruning or set `EXECUTIONS_DATA_MAX_AGE` in `.env` |
| Outline | Document content and file attachments; objects are stored in Garage S3 — scales with wiki content |
| FreeScout | Email history and file attachments |
| Invoice Ninja | Invoice PDFs and documents; base includes ~245 MB of static app assets that don't change |
| InvenTree | Parts database, parts images, and document attachments — scales with inventory size |
| Plane | Project data and file uploads — scales with team and issue volume |
| trigger.dev | Job run history — prune via the dashboard or `npx trigger.dev runs delete` |
| Garage | S3 objects from Outline and future services — scales with binary content stored |

For storage sizing guidance by database engine:

- [PostgreSQL disk usage](https://www.postgresql.org/docs/current/diskusage.html) — used by n8n, Outline, InvenTree, Plane, trigger.dev
- [MySQL / MariaDB table sizing](https://mariadb.com/kb/en/optimizing-table_size/) — used by FreeScout, Invoice Ninja

## Service Environment Files

Each service is configured via a `.env` file in its directory. These files hold service-specific secrets and settings — database passwords, API keys, encryption keys, port numbers, and initial admin credentials.

`.env` files are **git-ignored** and will never be committed. On first start, each service auto-generates secure random values for secrets and writes them to its `.env`, so the stack runs out of the box without manual configuration. **Review and update credentials before running in a production or externally-accessible environment.**

| Service | Config file | Key variables |
| ------- | ----------- | ------------- |
| Garage | `infrastructure/garage/.env` | `GARAGE_ACCESS_KEY_ID`, `GARAGE_SECRET_ACCESS_KEY` |
| n8n | `shared/n8n/.env` | `POSTGRES_PASSWORD`, `POSTGRES_NON_ROOT_PASSWORD` |
| Outline | `shared/outline/.env` | `DB_PASSWORD`, `SECRET_KEY`, `UTILS_SECRET` |
| FreeScout | `sales/freescout/.env` | `DB_PASSWORD`, `ADMIN_EMAIL`, `ADMIN_PASS` |
| Invoice Ninja | `accounting/invoiceninja/.env` | `DB_PASSWORD`, `DB_ROOT_PASSWORD`, `IN_USER_EMAIL`, `IN_PASSWORD` |
| InvenTree | `operations/inventree/.env` | `INVENTREE_DB_PASSWORD`, `INVENTREE_ADMIN_PASSWORD` |
| Plane | `shared/plane/.env` | `POSTGRES_PASSWORD`, `SECRET_KEY`, `RABBITMQ_PASSWORD` |
| trigger.dev | `shared/triggerdev/.env` | `POSTGRES_PASSWORD`, `ENCRYPTION_KEY`, `MAGIC_LINK_SECRET`, `SESSION_SECRET` |

---

## Prerequisites

- [Docker Engine 24+](https://docs.docker.com/engine/install/)
- [Docker Compose v2.20+](https://docs.docker.com/compose/install/)
- `openssl` — for automatic secret generation on first start

## Individual Service Control

Each service is started and stopped from its own directory:

```bash
cd accounting/invoiceninja && ./start.sh
cd sales/freescout && ./start.sh
cd operations/inventree && ./start.sh
cd infrastructure/garage && ./start.sh
cd shared/n8n && ./start.sh
cd shared/outline && ./start.sh   # start Garage first
cd shared/plane && ./start.sh
cd shared/triggerdev && ./start.sh
```

## First Run Notes

### Garage

- `GARAGE_ACCESS_KEY_ID` and `GARAGE_SECRET_ACCESS_KEY` are auto-generated and saved to `infrastructure/garage/.env` on first start
- The single-node cluster is initialized automatically (layout assign + apply)
- Must be running before starting Outline

### n8n

- `N8N_ENCRYPTION_KEY` and `RUNNERS_AUTH_TOKEN` are auto-generated and saved to `shared/n8n/.env` on first start
- Create your owner account on first visit to `http://localhost:5678`
- **Keep `shared/n8n/.env` backed up** — losing `N8N_ENCRYPTION_KEY` means losing access to all stored credentials

### Outline

- `SECRET_KEY`, `UTILS_SECRET`, and `DB_PASSWORD` are auto-generated and saved to `shared/outline/.env` on first start
- S3 credentials are auto-populated from `infrastructure/garage/.env` — **start Garage first**
- Requires an auth provider before any user can sign in: configure `OIDC_*` vars for OIDC (Keycloak, coming soon) or `SMTP_*` vars for magic-link email login
- The first user to sign in becomes the workspace owner — there are no default credentials
- **Do not change `SECRET_KEY` or `UTILS_SECRET` after first run** — they encrypt sessions and stored data

### FreeScout

- Database schema and admin account are created automatically on first start (~2–5 minutes)
- Set `ADMIN_EMAIL` and `ADMIN_PASS` in `sales/freescout/.env` before first run — these cannot be changed via `.env` after the database is initialised
- Default login: values of `ADMIN_EMAIL` / `ADMIN_PASS` in `sales/freescout/.env`

### Invoice Ninja

- `APP_KEY`, `DB_PASSWORD`, `DB_ROOT_PASSWORD`, and `IN_PASSWORD` are auto-generated and saved to `accounting/invoiceninja/.env` on first start
- Set `IN_USER_EMAIL` in `accounting/invoiceninja/.env` before first run to set the admin email
- **Do not change `APP_KEY` after first run** — it encrypts stored credentials and tokens
- Default login: value of `IN_USER_EMAIL` / `IN_PASSWORD` in `accounting/invoiceninja/.env`

### InvenTree

- `INVENTREE_DB_PASSWORD` and `INVENTREE_ADMIN_PASSWORD` are auto-generated and saved to `operations/inventree/.env` on first start
- `secret_key.txt` is auto-generated inside the data volume on first start — **back it up and never delete it**, as it encrypts stored credentials
- Database migrations run automatically on startup (`INVENTREE_AUTO_UPDATE=True`)
- Default login: `admin` / value of `INVENTREE_ADMIN_PASSWORD` in `operations/inventree/.env`

### Plane

- `SECRET_KEY`, `LIVE_SERVER_SECRET_KEY`, `POSTGRES_PASSWORD`, `RABBITMQ_PASSWORD`, `AWS_ACCESS_KEY_ID`, and `AWS_SECRET_ACCESS_KEY` are auto-generated and saved to `shared/plane/.env` on first start
- Create your workspace and owner account on first visit to `http://localhost:8100`
- **Do not change `SECRET_KEY` after first run** — it invalidates all active sessions

### trigger.dev

- `POSTGRES_PASSWORD`, `MAGIC_LINK_SECRET`, `SESSION_SECRET`, `ENCRYPTION_KEY`, `PROVIDER_SECRET`, and `COORDINATOR_SECRET` are auto-generated and saved to `shared/triggerdev/.env` on first start
- Uses magic link authentication — on first visit enter your email, then retrieve the login link from `docker logs trigger_webapp`
- **Never change `ENCRYPTION_KEY`, `MAGIC_LINK_SECRET`, or `SESSION_SECRET` after first run** — changing these breaks stored data or logs out all users
- The `docker-provider` and `coordinator` containers mount `/var/run/docker.sock` to spawn task worker containers on demand

## Data Persistence

All service data is stored in Docker named volumes scoped to each project. Stopping services preserves all data.

To remove a service's data volumes (destructive — cannot be undone):

```bash
cd <area>/<service> && ./stop.sh --volumes
```

## Architecture Notes

Each service is a separate Docker Compose project with its own network, volumes, and container namespace. They share only the host network interface (via distinct ports) and have no cross-service Docker networking by default.

| Service | Docker project | Database |
| ------- | ------------- | -------- |
| Garage | `garage` | — (is the object store) |
| n8n | `n8n` | PostgreSQL 17 |
| Outline | `outline` | PostgreSQL 17 + Redis 7 |
| FreeScout | `freescout` | MariaDB 11 |
| Invoice Ninja | `invoiceninja` | MySQL 8 |
| InvenTree | `inventree` | PostgreSQL 17 |
| Plane | `plane` | PostgreSQL 15 |
| trigger.dev | `triggerdev` | PostgreSQL 16 |

## License

MakerOps Core is licensed under the [PolyForm Shield License 1.0.0](LICENSE).

**Permitted:** Personal use, educational use, internal business operations, and setup/consulting services.
**Prohibited:** Selling or sublicensing the software, integrating it into commercial products sold to others, or offering it as a hosted or managed service.

Third-party software integrated by this stack is governed by its own license. See [NOTICE](NOTICE) for the full list of upstream projects and their licenses.
