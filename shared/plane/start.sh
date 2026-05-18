#!/bin/bash
# Starts the Plane project-management stack.
#
# First run:  generates all secrets, derives DATABASE_URL and AMQP_URL,
#             writes them back into .env, then pulls images and starts services.
# Subsequent runs: secrets already exist in .env — skips generation and starts.
set -e

PROJECT=plane
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ── Helpers ───────────────────────────────────────────────────────────────────

# If $var=GENERATE_ME in .env, replace it with openssl rand -hex $len output.
# Prints the current (or newly generated) value to stdout.
generate_if_needed() {
    local var="$1"
    local len="${2:-32}"   # byte count; hex output is 2× this
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

SECRET_KEY=$(generate_if_needed SECRET_KEY 32)
LIVE_SERVER_SECRET_KEY=$(generate_if_needed LIVE_SERVER_SECRET_KEY 32)
POSTGRES_PASSWORD=$(generate_if_needed POSTGRES_PASSWORD 16)
RABBITMQ_PASSWORD=$(generate_if_needed RABBITMQ_PASSWORD 16)
AWS_ACCESS_KEY_ID=$(generate_if_needed AWS_ACCESS_KEY_ID 16)
AWS_SECRET_ACCESS_KEY=$(generate_if_needed AWS_SECRET_ACCESS_KEY 32)

# ── Derive composed connection URLs ───────────────────────────────────────────
# Read the now-final values for URL construction.
POSTGRES_USER=$(grep "^POSTGRES_USER=" .env | cut -d= -f2-)
PGHOST=$(grep "^PGHOST=" .env | cut -d= -f2-)
PGDATABASE=$(grep "^PGDATABASE=" .env | cut -d= -f2-)
POSTGRES_PORT=$(grep "^POSTGRES_PORT=" .env | cut -d= -f2-)

RABBITMQ_USER=$(grep "^RABBITMQ_USER=" .env | cut -d= -f2-)
RABBITMQ_HOST=$(grep "^RABBITMQ_HOST=" .env | cut -d= -f2-)
RABBITMQ_PORT=$(grep "^RABBITMQ_PORT=" .env | cut -d= -f2-)
RABBITMQ_VHOST=$(grep "^RABBITMQ_VHOST=" .env | cut -d= -f2-)

derive_if_needed DATABASE_URL \
    "postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${PGHOST}:${POSTGRES_PORT}/${PGDATABASE}"

derive_if_needed AMQP_URL \
    "amqp://${RABBITMQ_USER}:${RABBITMQ_PASSWORD}@${RABBITMQ_HOST}:${RABBITMQ_PORT}/${RABBITMQ_VHOST}"

# ── Pull and start ─────────────────────────────────────────────────────────────
echo "Pulling images..."
docker compose -p "$PROJECT" pull --quiet

echo "Starting services..."
docker compose -p "$PROJECT" up -d

# ── Summary ───────────────────────────────────────────────────────────────────
WEB_URL=$(grep "^WEB_URL=" .env | cut -d= -f2-)
echo ""
echo "Plane is starting. Allow ~60 s for migrations and service init."
echo ""
echo "  UI:        ${WEB_URL:-http://localhost:8100}"
echo "  Admin:     ${WEB_URL:-http://localhost:8100}/god-mode/"
echo "  Spaces:    ${WEB_URL:-http://localhost:8100}/spaces/"
echo ""
echo "To tail logs:   docker compose -p $PROJECT logs -f"
echo "To tail one:    docker compose -p $PROJECT logs -f api"
