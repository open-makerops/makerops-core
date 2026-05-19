# name-proxy — Subdomain Access Proxy

name-proxy is a lightweight nginx-based reverse proxy built for makerops-core. It routes `*.localhost` subdomain requests to the corresponding service on its designated port, so any service in the stack can be reached by name instead of port number.

This is an internal service — it is not based on an external open-source project beyond the [nginx](https://nginx.org) web server it runs on. There is no upstream home page, issue tracker, or Docker Hub listing specific to this service.

---

## Why it exists

makerops-core runs a collection of independent services, each bound to its own port. Port-based access always works, but port numbers are harder to recall than service names:

```
http://localhost:8100   ← requires remembering which service owns :8100
http://plane.localhost  ← self-describing
```

As the number of deployed services grows, navigating by port becomes friction — especially when switching between services frequently or onboarding someone new to the stack. name-proxy exists purely as a convenience layer: it provides named access to every service in the stack without modifying how any of those services are deployed, configured, or networked.

---

## Optional

**This service is not required.** Every makerops-core service is fully accessible via its direct port regardless of whether name-proxy is running. Nothing in the stack depends on name-proxy, and no other service will break if it is stopped or never started.

| Access method | Example URL | Requires name-proxy |
|---|---|---|
| Port-based | `http://localhost:8100` | No |
| Subdomain-based | `http://plane.localhost` | Yes |

Port-based access is the baseline. Subdomain access is layered on top for convenience. Start name-proxy when you want named access; leave it stopped when you don't.

---

## DNS requirements

`*.localhost` resolves to `127.0.0.1` natively on **Linux** (including WSL2) and **macOS** — no configuration needed.

On **Windows** (native browser, not WSL2), subdomains of `.localhost` are not resolved automatically. Add an entry to `C:\Windows\System32\drivers\etc\hosts` for each subdomain you want to use:

```
127.0.0.1  n8n.localhost
127.0.0.1  outline.localhost
127.0.0.1  plane.localhost
127.0.0.1  trigger.localhost
127.0.0.1  freescout.localhost
127.0.0.1  invoiceninja.localhost
127.0.0.1  inventree.localhost
127.0.0.1  ollama.localhost
127.0.0.1  comfyui.localhost
127.0.0.1  wg.localhost
```

---

## Local Access

All services are available on port 80 — the default HTTP port — so no port number is needed in the browser URL.

| Subdomain | Service | Direct port equivalent |
|---|---|---|
| http://n8n.localhost | n8n — Workflow Automation | http://localhost:5678 |
| http://outline.localhost | Outline — Knowledge Base | http://localhost:3000 |
| http://plane.localhost | Plane — Project Management | http://localhost:8100 |
| http://trigger.localhost | trigger.dev — Background Jobs | http://localhost:3040 |
| http://freescout.localhost | FreeScout — Help Desk | http://localhost:8095 |
| http://invoiceninja.localhost | Invoice Ninja — Accounting | http://localhost:8092 |
| http://inventree.localhost | InvenTree — Inventory Management | http://localhost:8096 |
| http://ollama.localhost | Ollama — LLM Inference API | http://localhost:11434 |
| http://comfyui.localhost | ComfyUI — Image Generation | http://localhost:8188 |
| http://wg.localhost | WireGuard (wg-easy) — VPN Management | http://localhost:8820 |

Port values above are defaults. If you have changed a service's host port in its own `.env`, update the corresponding variable in name-proxy's `.env` to match.

---

## Scripts

### `./start.sh`

Creates `.env` from `.env.example` on first run if absent, pulls the latest `nginx:alpine` image, and starts the container. Prints the full subdomain → port mapping on completion.

```bash
./start.sh
```

### `./stop.sh`

Stops the container. name-proxy holds no persistent data, so nothing is lost.

```bash
./stop.sh
```

---

## Files

| File | Purpose |
|---|---|
| `.env` | Proxy listen port and per-service port overrides |
| `.env.example` | Default configuration template |
| `docker-compose.yml` | Single-container stack definition |
| `nginx/templates/default.conf.template` | nginx virtual host config; `${VAR}` placeholders are substituted at container startup via `envsubst` |
| `start.sh` | Pull and start |
| `stop.sh` | Stop |

### `.env` — values of interest

| Variable | Default | Corresponding service variable |
|---|---|---|
| `PROXY_PORT` | `80` | — |
| `N8N_PORT` | `5678` | `N8N_PORT_HOST` in `shared/n8n/.env` |
| `OUTLINE_PORT` | `3000` | `OUTLINE_PORT_HOST` in `shared/outline/.env` |
| `PLANE_PORT` | `8100` | `LISTEN_HTTP_PORT` in `shared/plane/.env` |
| `TRIGGERDEV_PORT` | `3040` | `LISTEN_PORT` in `shared/triggerdev/.env` |
| `FREESCOUT_PORT` | `8095` | `FREESCOUT_PORT` in `sales/freescout/.env` |
| `INVOICENINJA_PORT` | `8092` | `LISTEN_PORT` in `accounting/invoiceninja/.env` |
| `INVENTREE_PORT` | `8096` | `INVENTREE_WEB_PORT` in `operations/inventree/.env` |
| `OLLAMA_PORT` | `11434` | *(hard-coded default)* in `ai/ollama/.env` |
| `COMFYUI_PORT` | `8188` | `COMFYUI_PORT_HOST` in `ai/comfyui/.env` |
| `WG_PORT` | `8820` | `WG_UI_PORT` in `remote_access/wg-easy/.env` |

Defaults match each service's default host port. A value here only needs changing if the corresponding service's host port was overridden.

---

## Architecture

```
Browser
  └─► *.localhost:80
        └─► name-proxy  (nginx:alpine — port 80)
              │
              ├─► n8n.localhost          →  host.docker.internal:5678  (n8n)
              ├─► outline.localhost      →  host.docker.internal:3000  (Outline)
              ├─► plane.localhost        →  host.docker.internal:8100  (Plane)
              ├─► trigger.localhost      →  host.docker.internal:3040  (trigger.dev)
              ├─► freescout.localhost    →  host.docker.internal:8095  (FreeScout)
              ├─► invoiceninja.localhost →  host.docker.internal:8092  (Invoice Ninja)
              ├─► inventree.localhost    →  host.docker.internal:8096  (InvenTree)
              ├─► ollama.localhost       →  host.docker.internal:11434 (Ollama)
              ├─► comfyui.localhost      →  host.docker.internal:8188  (ComfyUI)
              └─► wg.localhost           →  host.docker.internal:8820  (wg-easy)
```

`host.docker.internal` resolves to the Docker host's loopback interface, reaching any service bound to a host port. On Linux, the compose file maps `host-gateway` to provide this address inside the container; on macOS and Windows it is provided automatically by Docker Desktop.

nginx is configured with WebSocket upgrade headers (`Upgrade`, `Connection`) at the http context level, so WebSocket connections are proxied transparently for all services that use them (n8n, trigger.dev, ComfyUI).

Port variables are substituted into the nginx config at container startup using `envsubst`. The `NGINX_ENVSUBST_TEMPLATE_VARS` environment variable scopes substitution to only the named port variables, leaving nginx runtime variables (`$host`, `$remote_addr`, etc.) untouched.

**Containers:**

| Container | Image | Role |
|---|---|---|
| `name-proxy` | `nginx:alpine` | Subdomain-to-port reverse proxy |

---

## Cheat Sheet

### Logs

```bash
docker logs name-proxy -f
```

### Verify routing

Test that a subdomain is correctly routed without opening a browser:

```bash
curl -si -H "Host: plane.localhost" http://localhost/ | head -5
# Expect: HTTP/1.1 200 or 3xx from the Plane service, not a 502 or nginx default page
```

A `502 Bad Gateway` means name-proxy is routing correctly but the target service is not running. A `404` from nginx means the `Host` header did not match any configured subdomain.

### Adding a service

1. Add a server block to `nginx/templates/default.conf.template`:

```nginx
# ── My Service ────────────────────────────────────────────────────────────────
server {
    listen      80;
    server_name myservice.localhost;
    location / { proxy_pass http://host.docker.internal:${MYSERVICE_PORT}; }
}
```

2. Add the variable to `docker-compose.yml` — in both `NGINX_ENVSUBST_TEMPLATE_VARS` and as an explicit environment entry:

```yaml
NGINX_ENVSUBST_TEMPLATE_VARS: "... MYSERVICE_PORT"
MYSERVICE_PORT: "${MYSERVICE_PORT:-NNNN}"
```

3. Add the default to `.env.example` and `.env`:

```
MYSERVICE_PORT=NNNN
```

4. Restart: `./stop.sh && ./start.sh`.
