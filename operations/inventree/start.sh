#!/bin/bash
# Starts the InvenTree inventory management stack.
#
# First run:  generates INVENTREE_DB_PASSWORD and INVENTREE_ADMIN_PASSWORD,
#             writes them back into .env, then pulls images and starts services.
# Subsequent runs: secrets already exist in .env — skips generation and starts.
#
# On first start InvenTree automatically:
#   1. Generates secret_key.txt in the data volume
#   2. Runs database migrations (INVENTREE_AUTO_UPDATE=True)
#   3. Creates the admin account from INVENTREE_ADMIN_USER/EMAIL/PASSWORD
#
# NOTE: The InvenTree Docker image (1.3.2+) runs gunicorn directly and does NOT
# call collectstatic on startup. INVENTREE_AUTO_UPDATE only handles migrations.
# collectstatic must be run explicitly after the server is up — handled below.
set -e

PROJECT=inventree
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ── Helpers ───────────────────────────────────────────────────────────────────

# If $var=GENERATE_ME in .env, replace with openssl rand -hex $len output.
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

# ── Generate secrets ──────────────────────────────────────────────────────────
echo "Checking secrets..."

generate_if_needed INVENTREE_DB_PASSWORD 16 > /dev/null
ADMIN_PASSWORD=$(generate_if_needed INVENTREE_ADMIN_PASSWORD 12)

# ── Pull and start ─────────────────────────────────────────────────────────────
echo "Pulling images..."
docker compose -p "$PROJECT" pull --quiet

echo "Starting services..."
docker compose -p "$PROJECT" up -d

# ── collectstatic ─────────────────────────────────────────────────────────────
# The image runs gunicorn directly and never calls collectstatic automatically.
# Collect static files so the React frontend assets are present in the shared
# data volume for Caddy to serve. Retry until the container process is ready.
echo "Collecting static files..."
for i in $(seq 1 15); do
    if docker compose -p "$PROJECT" exec -T inventree-server \
        python /home/inventree/src/backend/InvenTree/manage.py collectstatic --no-input --verbosity 0 --clear 2>/dev/null; then
        break
    fi
    sleep 2
done

# ── Summary ───────────────────────────────────────────────────────────────────
SITE_URL=$(grep "^INVENTREE_SITE_URL=" .env | cut -d= -f2-)
ADMIN_USER=$(grep "^INVENTREE_ADMIN_USER=" .env | cut -d= -f2-)

echo ""
echo "InvenTree is starting. Allow ~2 min for migrations and setup on first run."
echo ""
echo "  UI:       ${SITE_URL:-http://localhost:8096}"
echo "  Login:    ${ADMIN_USER:-admin}"
echo "  Password: ${ADMIN_PASSWORD}  (only valid on first run — change after login)"
echo ""
echo "To tail logs:  docker compose -p $PROJECT logs -f"
echo "To tail app:   docker compose -p $PROJECT logs -f inventree-server"
