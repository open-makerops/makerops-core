#!/bin/bash
# Tears down the trigger.dev stack completely.
# Removes all containers, volumes, images, and networks created by this service.
#
# WARNING: data volumes are permanently deleted. This cannot be undone.
# After teardown, re-running start.sh creates a fresh installation.
# Note: generated secrets in .env (ENCRYPTION_KEY, SESSION_SECRET, etc.)
#       are not reset — replace them with GENERATE_ME beforehand for a fully
#       fresh install so start.sh regenerates them on the next run.
set -e

PROJECT=triggerdev
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ── Enumerate what exists ──────────────────────────────────────────────────────
CONTAINERS=$(docker compose -p "$PROJECT" ps -a \
    --format "  {{.Name}}  ({{.Status}})" 2>/dev/null || true)
VOLUMES=$(docker volume ls \
    --filter "label=com.docker.compose.project=$PROJECT" \
    --format "  {{.Name}}" 2>/dev/null || true)
IMAGES=$(docker compose -p "$PROJECT" images 2>/dev/null \
    | awk 'NR>1 && $2!="<none>" {print "  "$2":"$3}' | sort -u || true)
NETWORKS=$(docker network ls \
    --filter "label=com.docker.compose.project=$PROJECT" \
    --format "  {{.Name}}" 2>/dev/null || true)

# ── Show what will be removed ──────────────────────────────────────────────────
echo "══════════════════════════════════════════"
echo "  trigger.dev — teardown"
echo "══════════════════════════════════════════"
echo ""
# ── Enumerate data directories ────────────────────────────────────────────────
DB_DATA_PATH=$(grep "^TRIGGERDEV_DB_DATA_PATH=" .env 2>/dev/null | cut -d= -f2- || echo "./data/postgres")
REDIS_DATA_PATH=$(grep "^TRIGGERDEV_REDIS_DATA_PATH=" .env 2>/dev/null | cut -d= -f2- || echo "./data/redis")
CH_DATA_PATH=$(grep "^TRIGGERDEV_CLICKHOUSE_DATA_PATH=" .env 2>/dev/null | cut -d= -f2- || echo "./data/clickhouse")
REG_DATA_PATH=$(grep "^TRIGGERDEV_REGISTRY_DATA_PATH=" .env 2>/dev/null | cut -d= -f2- || echo "./data/registry")
DATA_DIRS="${DB_DATA_PATH:-./data/postgres} ${REDIS_DATA_PATH:-./data/redis} ${CH_DATA_PATH:-./data/clickhouse} ${REG_DATA_PATH:-./data/registry}"

echo "The following Docker resources will be permanently removed:"
echo ""
echo "Containers:"
[[ -n "$CONTAINERS" ]] && echo "$CONTAINERS" || echo "  (none)"
echo ""
echo "Volumes  (ALL DATA WILL BE LOST):"
[[ -n "$VOLUMES" ]] && echo "$VOLUMES" || echo "  (none)"
echo ""
echo "Host data directories  (ALL DATA WILL BE LOST):"
for d in $DATA_DIRS; do
    [[ -d "$d" ]] && echo "  $d" || true
done
echo ""
echo "Images:"
[[ -n "$IMAGES" ]] && echo "$IMAGES" || echo "  (none)"
echo ""
echo "Networks:"
[[ -n "$NETWORKS" ]] && echo "$NETWORKS" || echo "  (none)"
echo ""
echo "──────────────────────────────────────────"
echo ""
read -r -p "Proceed with teardown? [y/N] " REPLY
echo ""

if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
    echo "Aborted — nothing was removed."
    exit 0
fi

# ── Remove everything ──────────────────────────────────────────────────────────
echo "Removing containers, volumes, images, and networks..."
docker compose -p "$PROJECT" down --volumes --rmi all --remove-orphans

echo "Removing host data directories..."
for d in $DATA_DIRS; do
    [[ -d "$d" ]] && rm -rf "$d" && echo "  Removed $d" || true
done
rm -f registry/auth.htpasswd

echo ""
echo "Done."
echo ""
echo "To create a fresh installation:"
echo "  cp .env.example .env"
echo "  ./start.sh"
