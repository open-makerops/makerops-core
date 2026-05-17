# InvenTree — Inventory & Parts Management

InvenTree is an open-source inventory management system designed for tracking parts, stock, assemblies, BOMs, purchase orders, and sales orders. It is well-suited for electronics labs, maker spaces, and small manufacturing operations.

- **Home page:** https://inventree.org
- **Docs:** https://docs.inventree.org
- **GitHub:** https://github.com/inventree/InvenTree
- **Docker Hub:** https://hub.docker.com/r/inventree/inventree/tags
- **API reference:** `http://localhost:8096/api/schema/` (OpenAPI, interactive at `/api/schema/swagger-ui/`)

---

## Attribution

**InvenTree** is open-source software developed and maintained by the InvenTree community. It is made freely available under the [MIT License](https://github.com/inventree/InvenTree/blob/master/LICENSE). The project is volunteer-driven and relies on community contributions for development, documentation, and support.

- **Support InvenTree:** [GitHub Sponsors](https://github.com/sponsors/inventree) · [Open Collective](https://opencollective.com/inventree)
- **Contribute:** [github.com/inventree/InvenTree](https://github.com/inventree/InvenTree) — bug reports, feature requests, and pull requests are all welcome

InvenTree does not currently offer an official cloud-hosted service. If you prefer not to manage the infrastructure yourself, some third-party integrators offer managed InvenTree deployments — check the [InvenTree community forums](https://github.com/inventree/InvenTree/discussions) for current recommendations.

---

## Local Access

| | |
|---|---|
| **URL** | http://localhost:8096 |
| **Username** | `admin` |
| **Password** | see `INVENTREE_ADMIN_PASSWORD` in `.env` |

The first page load takes a few extra seconds — the React app is large (~1.2 MB of JS) and needs to compile in the browser. This is normal.

---

## Scripts

### `./start.sh`

Starts the full stack. On **first run** it auto-generates `INVENTREE_DB_PASSWORD` and `INVENTREE_ADMIN_PASSWORD` in `.env` (replacing `GENERATE_ME` placeholders), pulls images, and brings all services up. Subsequent runs skip secret generation and just start the containers.

First-run startup takes ~2 minutes while InvenTree runs database migrations and creates the admin account.

```bash
./start.sh
```

### `./stop.sh`

Stops all containers. Data volumes are preserved.

```bash
./stop.sh
```

Pass `--volumes` to also remove volumes (destructive — all data is lost):

```bash
./stop.sh --volumes
```

### `./teardown.sh`

Interactive full teardown. Lists all containers, volumes, images, and networks that will be removed, prompts for confirmation, then wipes everything. Use this to start completely fresh.

```bash
./teardown.sh
```

To get a truly clean re-install (new secrets too), replace the generated secrets with `GENERATE_ME` before re-running `start.sh`:

```bash
sed -i 's/^INVENTREE_DB_PASSWORD=.*/INVENTREE_DB_PASSWORD=GENERATE_ME/' .env
sed -i 's/^INVENTREE_ADMIN_PASSWORD=.*/INVENTREE_ADMIN_PASSWORD=GENERATE_ME/' .env
```

---

## Files

| File | Purpose |
|---|---|
| `.env` | All runtime configuration and secrets |
| `docker-compose.yml` | Defines the 5-container stack |
| `Caddyfile` | Caddy reverse proxy rules |
| `spa_helper.py` | Patched Django template tag (see [Known Issues](#known-issues)) |
| `start.sh` | Start / first-run setup script |
| `stop.sh` | Stop (volumes preserved) |
| `teardown.sh` | Full wipe with confirmation prompt |

### `.env` — values of interest

| Variable | Value | Notes |
|---|---|---|
| `INVENTREE_TAG` | `1.3.2` | Docker image tag; change to `stable` to track latest stable |
| `INVENTREE_WEB_PORT` | `8096` | Host port; must not conflict with other services |
| `INVENTREE_SITE_URL` | `http://localhost:8096` | Must match the URL used in the browser |
| `INVENTREE_FRONTEND_SETTINGS` | `{"server_list": {...}}` | Passes the server list to the React SPA in object form; changing this to a list breaks the app |
| `INVENTREE_AUTO_UPDATE` | `True` | Runs `collectstatic` and DB migrations on every container restart (makes restarts slow ~30 s) |
| `INVENTREE_ADMIN_USER` | `admin` | Admin username (set once at DB creation; ignored after) |
| `INVENTREE_ADMIN_PASSWORD` | *(generated)* | Admin password (set once; change via UI after first login) |
| `INVENTREE_DB_PASSWORD` | *(generated)* | PostgreSQL password |
| `INVENTREE_PLUGINS_ENABLED` | `True` | Enables the plugin system |
| `INVENTREE_LOG_LEVEL` | `WARNING` | Set to `INFO` or `DEBUG` for verbose output |
| `INVENTREE_GUNICORN_TIMEOUT` | `90` | Request timeout in seconds |

---

## Architecture

```
Browser
  └─► localhost:8096
        └─► inventree_proxy  (Caddy)
              ├─► /static/*  →  inventree_data volume  (served directly)
              ├─► /media/*   →  inventree_data volume  (forward-auth check first)
              └─► /*         →  inventree_server:8000  (Gunicorn / Django)
                                  ├─► inventree_db:5432   (PostgreSQL)
                                  └─► inventree_cache:6379 (Redis)
                                inventree_worker  (Django-Q background tasks)
```

**Containers:**

| Container | Image | Role |
|---|---|---|
| `inventree_db` | `postgres:17-alpine` | Application database |
| `inventree_cache` | `redis:7-alpine` | Cache and task queue |
| `inventree_server` | `inventree/inventree:1.3.2` | Django/Gunicorn app server |
| `inventree_worker` | `inventree/inventree:1.3.2` | Background task worker |
| `inventree_proxy` | `caddy:2-alpine` | Reverse proxy, static/media files |

**Volumes:**

| Volume | Contents |
|---|---|
| `inventree_data` | Static files, media uploads, config, secret key |
| `inventree_pgdata` | PostgreSQL data |
| `inventree_cache` | Redis persistence |

---

## Cheat Sheet

### Logs

```bash
# All services
docker compose -p inventree logs -f

# App server only (Django/Gunicorn)
docker logs inventree_server -f

# Proxy access log
docker logs inventree_proxy -f

# Background worker
docker logs inventree_worker -f
```

### Container shell access

```bash
docker exec -it inventree_server bash
docker exec -it inventree_db psql -U inventree inventree
docker exec -it inventree_cache redis-cli
```

### Django management commands

```bash
# Run any Django management command
docker exec inventree_server python manage.py <command>

# Open Django shell
docker exec -it inventree_server python manage.py shell

# Manually run collectstatic
docker exec inventree_server invoke static

# Manually run migrations
docker exec inventree_server invoke migrate

# Create a superuser
docker exec -it inventree_server python manage.py createsuperuser
```

### Reset admin password

```bash
docker exec -it inventree_server python manage.py changepassword admin
```

### Check worker status

```bash
# Workers report pending tasks and health in logs
docker logs inventree_worker --tail 20

# Or via the API
curl http://localhost:8096/api/ | python3 -m json.tool | grep worker
```

### Upgrade InvenTree

1. Edit `INVENTREE_TAG` in `.env` to the new version tag
2. `./stop.sh && ./start.sh`
3. `INVENTREE_AUTO_UPDATE=True` will run migrations automatically on startup

---

## Known Issues

### `spa_helper.py` patch (INVE-E1 workaround)

InvenTree 1.3.2's `spa_bundle` Django template tag omits two things that are required for the React SPA to mount within its 1-second timeout window:

1. **Missing `<link rel="modulepreload">`** for `ThemeContext-RRVgNtVr.js` (~400 KB), which is a static import of both `MobileAppView` and `DesktopAppView` chunks. Without the hint, the browser discovers and downloads it sequentially after parsing each chunk, creating a cascade delay that pushes past the timeout.

2. **Missing `<link rel="stylesheet">`** for the entry-point CSS (`index-DPZ5Al3u.css`, ~274 KB Mantine UI styles).

The fix is `spa_helper.py` in this directory, mounted read-only into the server container:

```yaml
- ./spa_helper.py:/home/inventree/src/backend/InvenTree/web/templatetags/spa_helper.py:ro
```

If you upgrade InvenTree, check whether the upstream `spa_helper.py` has been fixed. If so, remove the volume mount from `docker-compose.yml` and delete `spa_helper.py`. The upstream file lives at:

```
/home/inventree/src/backend/InvenTree/web/templatetags/spa_helper.py
```

inside the container.

### `INVENTREE_FRONTEND_SETTINGS` must be an object

The `server_list` value **must** be a JSON object (not an array). Sending an array causes a `TypeError` in the React SPA before it can mount, triggering INVE-E1.

```
# Correct:
INVENTREE_FRONTEND_SETTINGS={"server_list": {"server-current": {"host": "http://localhost:8096/", "name": "InvenTree"}}}

# Wrong (crashes React):
INVENTREE_FRONTEND_SETTINGS={"server_list": []}
```

### Slow restarts (~30 seconds)

`INVENTREE_AUTO_UPDATE=True` causes the server container to run `invoke update` (which includes `collectstatic --clear` and DB migrations) on every startup. This is intentional but means restarts take ~30 seconds before the app is responsive.

---

## Debugging

### Check if the app is up

```bash
curl -s http://localhost:8096/api/ | python3 -m json.tool
```

A healthy response includes `"server": "InvenTree"`, version, worker status, and active plugins.

### INVE-E1 in the browser

This error appears when the React app fails to mount within 1 second. Causes to check:

- Are all containers running? `docker ps | grep inventree`
- Is the `spa_helper.py` volume mount still present? `docker inspect inventree_server | grep spa_helper`
- Did collectstatic run? `docker logs inventree_server | grep -i static`
- Are static files present? `docker exec inventree_proxy ls /var/www/static/web/assets/ | wc -l` (should be ~600+)
- Try a hard refresh in the browser (Ctrl+Shift+R) to bypass cached files

### Static files not loading

Caddy serves `/static/*` directly from the `inventree_data` volume mounted at `/var/www`. If files are missing, re-run collectstatic:

```bash
docker exec inventree_server invoke static
```

### Database connection issues

```bash
docker exec inventree_db pg_isready -U inventree -d inventree
```

### Caddy reload (after editing Caddyfile)

```bash
docker exec inventree_proxy caddy reload --config /etc/caddy/Caddyfile
```

### View the Vite manifest (maps JS chunk filenames)

```bash
docker exec inventree_server python3 -c "
import json
m = json.load(open('/home/inventree/src/backend/InvenTree/web/static/web/.vite/manifest.json'))
print(json.dumps(m.get('index.html'), indent=2))
"
```

### Useful API endpoints

| Endpoint | Description |
|---|---|
| `/api/` | Server info, version, worker status |
| `/api/part/` | Parts list |
| `/api/stock/` | Stock items |
| `/api/order/po/` | Purchase orders |
| `/api/order/so/` | Sales orders |
| `/api/schema/swagger-ui/` | Interactive API docs |
| `/django-admin/` | Django admin panel |
