#!/bin/bash
# Starts the trigger.dev background-jobs stack.
#
# First run:  generates all secrets, derives DATABASE_URL and DIRECT_URL,
#             writes them back into .env, then pulls images and starts services.
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

# ── Generate independent secrets ──────────────────────────────────────────────
echo "Checking secrets..."

POSTGRES_PASSWORD=$(generate_if_needed POSTGRES_PASSWORD 16)
MAGIC_LINK_SECRET=$(generate_if_needed MAGIC_LINK_SECRET 32)
SESSION_SECRET=$(generate_if_needed SESSION_SECRET 32)
ENCRYPTION_KEY=$(generate_if_needed ENCRYPTION_KEY 16)
PROVIDER_SECRET=$(generate_if_needed PROVIDER_SECRET 16)
COORDINATOR_SECRET=$(generate_if_needed COORDINATOR_SECRET 16)

# ── Derive connection URLs ─────────────────────────────────────────────────────
POSTGRES_USER=$(grep "^POSTGRES_USER=" .env | cut -d= -f2-)
POSTGRES_DB=$(grep "^POSTGRES_DB=" .env | cut -d= -f2-)

DB_URL="postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB}"
derive_if_needed DATABASE_URL "$DB_URL"
derive_if_needed DIRECT_URL   "$DB_URL"

# ── Pull and start ─────────────────────────────────────────────────────────────
echo "Pulling images..."
docker compose -p "$PROJECT" pull --quiet

echo "Starting services..."
docker compose -p "$PROJECT" up -d

# ── Summary ───────────────────────────────────────────────────────────────────
LISTEN_PORT=$(grep "^LISTEN_PORT=" .env | cut -d= -f2-)
TRIGGER_PROTOCOL=$(grep "^TRIGGER_PROTOCOL=" .env | cut -d= -f2-)
TRIGGER_DOMAIN=$(grep "^TRIGGER_DOMAIN=" .env | cut -d= -f2-)
UI_URL="${TRIGGER_PROTOCOL:-http}://${TRIGGER_DOMAIN:-localhost:${LISTEN_PORT:-3040}}"

echo ""
echo "trigger.dev is starting. Allow ~30 s for the webapp to become ready."
echo ""
echo "  UI:  $UI_URL"
echo ""
echo "First-run authentication (magic link):"
echo "  1. Open the UI URL above and enter your email address"
echo "  2. Retrieve the magic link from the webapp logs:"
echo "       docker logs trigger_webapp 2>&1 | grep -i 'magic\|login'"
echo "  3. Open the link in your browser to complete sign-in"
echo ""
echo "To tail logs:  docker compose -p $PROJECT logs -f"
echo "To tail one:   docker compose -p $PROJECT logs -f webapp"
