#!/bin/bash
# Starts the trigger.dev v4 background-jobs stack.
#
# First run:  generates all secrets, derives URLs, sources Garage object-store
#             credentials, creates the Garage bucket, generates the registry
#             htpasswd file, then pulls images and starts services.
# Subsequent runs: secrets already exist in .env — skips generation and starts.
set -e

PROJECT=triggerdev
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ── Helpers ───────────────────────────────────────────────────────────────────

# If $var=GENERATE_ME in .env, replace it with openssl rand -hex $len output.
# Prints the current (or newly generated) value to stdout.
generate_if_needed() {
    local var="$1"
    local len="${2:-32}"
    if grep -q "^${var}=GENERATE_ME" .env 2>/dev/null; then
        local val
        val=$(openssl rand -hex "$len")
        sed -i "s|^${var}=GENERATE_ME|${var}=${val}|" .env
        echo "  Generated ${var}." >&2
        echo "$val"
    else
        grep "^${var}=" .env | cut -d= -f2-
    fi
}

# If $var=GENERATE_ME in .env, replace it with the provided value.
derive_if_needed() {
    local var="$1"
    local val="$2"
    if grep -q "^${var}=GENERATE_ME" .env 2>/dev/null; then
        sed -i "s|^${var}=GENERATE_ME|${var}=${val}|" .env
        echo "  Derived  ${var}." >&2
    fi
}

# Always overwrite $var in .env with the provided value.
set_env_var() {
    local var="$1"
    local val="$2"
    if grep -q "^${var}=" .env 2>/dev/null; then
        sed -i "s|^${var}=.*|${var}=${val}|" .env
    fi
}

# ── Generate independent secrets ──────────────────────────────────────────────
echo "Checking secrets..."

POSTGRES_PASSWORD=$(generate_if_needed POSTGRES_PASSWORD 16)
MAGIC_LINK_SECRET=$(generate_if_needed MAGIC_LINK_SECRET 32)
SESSION_SECRET=$(generate_if_needed SESSION_SECRET 32)
ENCRYPTION_KEY=$(generate_if_needed ENCRYPTION_KEY 16)
MANAGED_WORKER_SECRET=$(generate_if_needed MANAGED_WORKER_SECRET 32)
CLICKHOUSE_PASSWORD=$(generate_if_needed CLICKHOUSE_PASSWORD 16)
DOCKER_REGISTRY_PASSWORD=$(generate_if_needed DOCKER_REGISTRY_PASSWORD 16)

# ── Derive connection URLs ─────────────────────────────────────────────────────
POSTGRES_USER=$(grep "^POSTGRES_USER=" .env | cut -d= -f2-)
POSTGRES_DB=$(grep "^POSTGRES_DB=" .env | cut -d= -f2-)
TRIGGER_PROTOCOL=$(grep "^TRIGGER_PROTOCOL=" .env | cut -d= -f2-)
TRIGGER_DOMAIN=$(grep "^TRIGGER_DOMAIN=" .env | cut -d= -f2-)
CLICKHOUSE_USER=$(grep "^CLICKHOUSE_USER=" .env | cut -d= -f2-)
DOCKER_REGISTRY_USERNAME=$(grep "^DOCKER_REGISTRY_USERNAME=" .env | cut -d= -f2-)

DB_URL="postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB}"
derive_if_needed DATABASE_URL "$DB_URL"
derive_if_needed DIRECT_URL   "$DB_URL"

ORIGIN="${TRIGGER_PROTOCOL:-http}://${TRIGGER_DOMAIN:-localhost:3040}"
derive_if_needed APP_ORIGIN   "$ORIGIN"
derive_if_needed LOGIN_ORIGIN "$ORIGIN"
derive_if_needed API_ORIGIN   "$ORIGIN"

CH_URL="http://${CLICKHOUSE_USER:-default}:${CLICKHOUSE_PASSWORD}@clickhouse:8123?secure=false"
CH_REPL_URL="http://${CLICKHOUSE_USER:-default}:${CLICKHOUSE_PASSWORD}@clickhouse:8123"
derive_if_needed CLICKHOUSE_URL                 "$CH_URL"
derive_if_needed RUN_REPLICATION_CLICKHOUSE_URL "$CH_REPL_URL"

# ── Source Garage object-store credentials ────────────────────────────────────
GARAGE_ENV="${SCRIPT_DIR}/../../infrastructure/garage/.env"
if [[ ! -f "$GARAGE_ENV" ]]; then
    echo ""
    echo "ERROR: Garage service .env not found at:"
    echo "         ${GARAGE_ENV}"
    echo "       Start Garage first: makerops-core/infrastructure/garage/start.sh"
    exit 1
fi
if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^garage$'; then
    echo ""
    echo "ERROR: Garage container is not running."
    echo "       Start Garage first: makerops-core/infrastructure/garage/start.sh"
    exit 1
fi
# shellcheck source=/dev/null
source "$GARAGE_ENV"
set_env_var OBJECT_STORE_ACCESS_KEY_ID     "$GARAGE_ACCESS_KEY_ID"
set_env_var OBJECT_STORE_SECRET_ACCESS_KEY "$GARAGE_SECRET_ACCESS_KEY"
echo "  Sourced Garage credentials."

# ── Create Garage bucket for trigger.dev ──────────────────────────────────────
if docker exec garage /garage bucket list 2>/dev/null | grep -qF 'packets'; then
    echo "  Garage bucket 'packets' already exists."
else
    echo "  Creating Garage bucket 'packets'..."
    docker exec garage /garage bucket create packets
    docker exec garage /garage bucket allow --read --write --owner packets --key default
fi

# ── Generate registry htpasswd ────────────────────────────────────────────────
REGISTRY_DIR="${SCRIPT_DIR}/registry"
mkdir -p "$REGISTRY_DIR"
HTPASSWD_FILE="${REGISTRY_DIR}/auth.htpasswd"
if [[ ! -f "$HTPASSWD_FILE" ]]; then
    HTPASSWD_HASH=$(openssl passwd -apr1 "$DOCKER_REGISTRY_PASSWORD")
    echo "${DOCKER_REGISTRY_USERNAME:-registry}:${HTPASSWD_HASH}" > "$HTPASSWD_FILE"
    echo "  Generated registry/auth.htpasswd."
else
    echo "  Registry auth.htpasswd already exists."
fi

# ── Pull and start ─────────────────────────────────────────────────────────────
echo "Pulling images..."
docker compose -p "$PROJECT" pull --quiet

echo "Starting services..."
docker compose -p "$PROJECT" up -d

# ── Summary ───────────────────────────────────────────────────────────────────
LISTEN_PORT=$(grep "^LISTEN_PORT=" .env | cut -d= -f2-)
UI_URL="${TRIGGER_PROTOCOL:-http}://${TRIGGER_DOMAIN:-localhost:${LISTEN_PORT:-3040}}"

echo ""
echo "trigger.dev v4 is starting. Allow ~60 s for all services to become healthy."
echo ""
echo "  UI:  $UI_URL"
echo ""
echo "First-run authentication (magic link):"
echo "  1. Open the UI URL above and enter your email address"
echo "  2. Retrieve the magic link from the webapp logs:"
echo "       docker logs trigger_webapp 2>&1 | grep -i 'magic\|login'"
echo "  3. Open the link in your browser to complete sign-in"
echo ""
echo "NOTE: Docker daemon must allow the local registry as an insecure registry."
echo "  Add to /etc/docker/daemon.json:  { \"insecure-registries\": [\"localhost:5000\"] }"
echo "  Then restart Docker and re-run this script."
echo ""
echo "To tail logs:  docker compose -p $PROJECT logs -f"
echo "To tail one:   docker compose -p $PROJECT logs -f webapp"
