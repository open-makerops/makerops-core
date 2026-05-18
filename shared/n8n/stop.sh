#!/bin/bash
# Stops all n8n services. Data volumes are preserved.
# Pass --volumes to also remove db_storage, n8n_storage, redis_storage (destructive).
set -e

PROJECT=n8n

docker compose -p "$PROJECT" down "$@"
