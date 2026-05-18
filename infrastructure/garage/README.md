# Garage — S3-Compatible Object Store

Garage is a lightweight, self-hostable S3-compatible object store designed for geo-distributed deployments but equally suited to single-node use. It exposes a standard S3 API, making it a drop-in backend for applications that support S3 storage (Outline, Nextcloud, Plane, etc.).

- **Home page:** https://garagehq.deuxfleurs.fr
- **Docs:** https://garagehq.deuxfleurs.fr/documentation/quick-start/
- **GitHub:** https://github.com/deuxfleurs-org/garage
- **Docker image:** https://hub.docker.com/r/dxflrs/garage

---

## Attribution

**Garage** is open-source software developed and maintained by the Deuxfleurs cooperative and contributors. It is made freely available under the [AGPL-3.0 License](https://github.com/deuxfleurs-org/garage/blob/main/LICENSE).

- **Support Garage:** [Deuxfleurs Open Collective](https://opencollective.com/deuxfleurs)

---

## Local Access

| | |
|---|---|
| **S3 API** | http://localhost:3900 |
| **Admin API** | http://localhost:3903 |
| **S3 region** | `garage` |
| **Key ID** | see `.env` → `GARAGE_ACCESS_KEY_ID` (written on first start) |
| **Secret key** | see `.env` → `GARAGE_SECRET_ACCESS_KEY` (written on first start) |

---

## Scripts

### `./start.sh`

On **first run**, generates `garage.toml` from `garage.toml.example` (substituting secrets), starts the container, initializes the single-node cluster (layout assign + apply), creates a default S3 key, and writes its credentials into `.env`. Subsequent runs skip all initialization and just start the container.

```bash
./start.sh
```

### `./stop.sh`

Stops the container. Data in `./data/` is preserved.

```bash
./stop.sh
```

### `./teardown.sh`

Interactive full teardown: lists what will be removed, prompts for confirmation, then deletes all containers, volumes, images, and networks. The `./data/` bind mount directory is listed separately — delete it manually for a complete wipe.

```bash
./teardown.sh
```

To fully reset (new secrets, fresh data):

```bash
./teardown.sh
rm -rf ./data/ ./garage.toml
# Reset credentials in .env back to empty
sed -i 's/^GARAGE_ACCESS_KEY_ID=.*/GARAGE_ACCESS_KEY_ID=/' .env
sed -i 's/^GARAGE_SECRET_ACCESS_KEY=.*/GARAGE_SECRET_ACCESS_KEY=/' .env
./start.sh
```

---

## Files

| File | Purpose |
|---|---|
| `.env` | Image version, S3 key credentials, optional data path overrides |
| `garage.toml` | Active Garage configuration (generated, gitignored) |
| `garage.toml.example` | Configuration template; secrets are placeholders |
| `docker-compose.yml` | Single-container stack definition |
| `data/meta/` | Garage metadata storage (LMDB database) |
| `data/objects/` | Garage object data storage |
| `start.sh` | Start / first-run setup and cluster initialization |
| `stop.sh` | Stop (data preserved) |
| `teardown.sh` | Full wipe with confirmation |

### `.env` — values of interest

| Variable | Value | Notes |
|---|---|---|
| `GARAGE_VERSION` | `v2.3.0` | Pinned image tag |
| `GARAGE_ACCESS_KEY_ID` | *(generated)* | Default S3 key ID; written on first start |
| `GARAGE_SECRET_ACCESS_KEY` | *(generated)* | Default S3 secret; written on first start |

> **Security note:** `GARAGE_ACCESS_KEY_ID` and `GARAGE_SECRET_ACCESS_KEY` in `.env` grant full access to all buckets on this Garage instance. Keep `.env` out of version control (it is gitignored).

---

## Architecture

```
S3 client (e.g. Outline)
  └─► localhost:3900  (S3 API — PUT/GET/DELETE objects)

Admin tools / CLI
  └─► localhost:3903  (Admin API — manage keys, buckets, cluster)

  └─► garage  (dxflrs/garage — single-node cluster)
        ├─► /var/lib/garage/meta  →  ./data/meta   (LMDB metadata)
        └─► /var/lib/garage/data  →  ./data/objects (object data)
```

**Containers:**

| Container | Image | Role |
|---|---|---|
| `garage` | `dxflrs/garage:v2.3.0` | S3 API + Admin API |

**Bind mounts (local directories):**

| Directory | Contents |
|---|---|
| `./data/meta/` | Garage metadata database (LMDB) — keep on fast storage |
| `./data/objects/` | Object data — can be on a large/slow disk |

These directories are created on first start. Back them up to preserve all stored objects.

---

## Cheat Sheet

### Logs

```bash
docker logs garage -f
```

### Shell access

```bash
# The Garage image has no shell — use docker exec with the garage binary directly
docker exec garage /garage status
```

### Cluster status

```bash
docker exec garage /garage status
```

### Manage buckets

```bash
# List buckets
docker exec garage /garage bucket list

# Create a bucket
docker exec garage /garage bucket create my-bucket

# Allow the default key to read/write a bucket
docker exec garage /garage bucket allow \
  --read --write --owner my-bucket \
  --key default
```

### Manage keys

```bash
# List keys
docker exec garage /garage key list

# Show key details (ID + secret)
docker exec garage /garage key info default

# Create a new key
docker exec garage /garage key create my-service-key
```

### Test the S3 API

Requires the [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html):

```bash
# Source credentials from .env
export AWS_ACCESS_KEY_ID=$(grep GARAGE_ACCESS_KEY_ID .env | cut -d= -f2-)
export AWS_SECRET_ACCESS_KEY=$(grep GARAGE_SECRET_ACCESS_KEY .env | cut -d= -f2-)
export AWS_DEFAULT_REGION=garage

# Create a test bucket
aws --endpoint-url http://localhost:3900 s3 mb s3://test-bucket

# Upload a file
aws --endpoint-url http://localhost:3900 s3 cp myfile.txt s3://test-bucket/

# List objects
aws --endpoint-url http://localhost:3900 s3 ls s3://test-bucket/
```

### Upgrade Garage

1. Update `GARAGE_VERSION` in `.env` to the new tag
2. `./stop.sh`
3. `./start.sh` — pulls the new image and starts (layout is already initialized, so init steps are skipped)

---

## Debugging

### Container not starting

```bash
docker logs garage --tail 50
```

### Node has no layout / S3 API returns errors

If the cluster was not initialized correctly (rare if using `start.sh`), run manually:

```bash
NODE_ID=$(docker exec garage /garage node id | awk '{print $1}')
docker exec garage /garage layout assign -z dc1 -c 1G "$NODE_ID"
docker exec garage /garage layout apply --version 1
```

Then re-create the key:

```bash
docker exec garage /garage key create default
```

### Admin API returns 401

The `admin_token` in `garage.toml` is required for most admin API calls. It is set during first-run generation and is not available as a plain-text value in `.env`. Read it directly from `garage.toml` if needed:

```bash
grep admin_token garage.toml
```
