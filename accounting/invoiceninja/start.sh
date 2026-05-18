#!/bin/bash
# Starts the Invoice Ninja accounting stack.
#
# First run:  generates APP_KEY, DB_PASSWORD, DB_ROOT_PASSWORD, and an initial
#             IN_PASSWORD, writes them back into .env, then starts the stack.
# Subsequent runs: all secrets already exist in .env — skips generation.
#
# First-startup sequence (handled inside the in-app container by init.sh):
#   1. php artisan migrate --force
#   2. php artisan db:seed --force   (only if no account exists yet)
#   3. php artisan ninja:create-account --email <IN_USER_EMAIL> --password <IN_PASSWORD>
set -e

PROJECT=invoiceninja
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ── Helpers ───────────────────────────────────────────────────────────────────

# Replace VAR=GENERATE_ME in .env with a hex secret of $len bytes.
# Prints the current (or newly generated) value to stdout.
generate_if_needed() {
    local var="$1"
    local len="${2:-16}"
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

# ── Generate database passwords ───────────────────────────────────────────────
echo "Checking secrets..."

generate_if_needed DB_PASSWORD     16  > /dev/null
generate_if_needed DB_ROOT_PASSWORD 16  > /dev/null

# ── Generate initial admin password ──────────────────────────────────────────
# Only generated once (before first container run). After the account is
# created in the DB, IN_PASSWORD has no further effect.
if grep -q "^IN_PASSWORD=GENERATE_ME" .env 2>/dev/null; then
    PASS=$(openssl rand -base64 12 | tr -d '+/=')
    sed -i "s|^IN_PASSWORD=GENERATE_ME|IN_PASSWORD=${PASS}|" .env
    echo "  Generated IN_PASSWORD." >&2
fi

# ── Generate Laravel APP_KEY ─────────────────────────────────────────────────
# Laravel expects: base64:<44-char base64-encoded 32-byte key>
# We derive this with openssl — no need to pull the image first.
if grep -q "^APP_KEY=GENERATE_ME" .env 2>/dev/null; then
    KEY="base64:$(openssl rand -base64 32)"
    sed -i "s|^APP_KEY=GENERATE_ME|APP_KEY=${KEY}|" .env
    echo "  Generated APP_KEY." >&2
fi

# ── Pull and start ─────────────────────────────────────────────────────────────
echo "Pulling images..."
docker compose -p "$PROJECT" pull --quiet

echo "Starting services..."
docker compose -p "$PROJECT" up -d

# ── Summary ───────────────────────────────────────────────────────────────────
APP_URL=$(grep "^APP_URL=" .env | cut -d= -f2-)
IN_USER_EMAIL=$(grep "^IN_USER_EMAIL=" .env | cut -d= -f2-)
IN_PASSWORD=$(grep "^IN_PASSWORD=" .env | cut -d= -f2-)

echo ""
echo "Invoice Ninja is starting. Allow ~90 s for migrations on first run."
echo ""
echo "  UI:      ${APP_URL:-http://localhost:8092}"
echo "  Login:   ${IN_USER_EMAIL:-admin@example.com}"
echo "  Password: ${IN_PASSWORD}  (only valid on first run — change after login)"
echo ""
echo "To tail logs:  docker compose -p $PROJECT logs -f"
echo "To tail app:   docker compose -p $PROJECT logs -f in-app"
