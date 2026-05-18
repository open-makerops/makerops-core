#!/bin/bash
# Starts the Outline knowledge base stack.
#
# First run:
#   - Copies .env.example → .env if .env does not exist
#   - Generates SECRET_KEY, UTILS_SECRET, and DB_PASSWORD
#   - Auto-populates S3 credentials from infrastructure/garage/.env
#   - Pulls images and starts services (migrations run automatically)
#   - Creates and configures the 'outline' bucket in Garage
# Subsequent runs:
#   - Skips secret generation (values already set) and starts services
set -e

PROJECT=outline
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ── Bootstrap .env ────────────────────────────────────────────────────────────
if [[ ! -f .env ]]; then
    echo "Creating .env from .env.example..."
    cp .env.example .env
fi

# ── Generate secrets on first run ─────────────────────────────────────────────
if grep -q "^SECRET_KEY=OVERWRITE_ME" .env 2>/dev/null; then
    echo "Generating SECRET_KEY..."
    KEY=$(openssl rand -hex 32)
    sed -i "s|^SECRET_KEY=OVERWRITE_ME|SECRET_KEY=${KEY}|" .env
    echo "  SECRET_KEY saved."
fi

if grep -q "^UTILS_SECRET=OVERWRITE_ME" .env 2>/dev/null; then
    echo "Generating UTILS_SECRET..."
    KEY=$(openssl rand -hex 32)
    sed -i "s|^UTILS_SECRET=OVERWRITE_ME|UTILS_SECRET=${KEY}|" .env
    echo "  UTILS_SECRET saved."
fi

if grep -q "^DB_PASSWORD=OVERWRITE_ME" .env 2>/dev/null; then
    echo "Generating DB_PASSWORD..."
    PASS=$(openssl rand -hex 16)
    sed -i "s|^DB_PASSWORD=OVERWRITE_ME|DB_PASSWORD=${PASS}|" .env
    echo "  DB_PASSWORD saved."
fi

# ── Auto-populate Garage S3 credentials ───────────────────────────────────────
GARAGE_ENV="${SCRIPT_DIR}/../../infrastructure/garage/.env"

CURRENT_KEY_ID=$(grep "^AWS_ACCESS_KEY_ID=" .env | sed 's/^AWS_ACCESS_KEY_ID=//' | tr -d '[:space:]')
if [[ -z "$CURRENT_KEY_ID" ]]; then
    if [[ -f "$GARAGE_ENV" ]]; then
        GARAGE_KEY_ID=$(grep "^GARAGE_ACCESS_KEY_ID=" "$GARAGE_ENV" | sed 's/^GARAGE_ACCESS_KEY_ID=//' | tr -d '[:space:]')
        GARAGE_SECRET=$(grep "^GARAGE_SECRET_ACCESS_KEY=" "$GARAGE_ENV" | sed 's/^GARAGE_SECRET_ACCESS_KEY=//' | tr -d '[:space:]')

        if [[ -z "$GARAGE_KEY_ID" ]]; then
            echo ""
            echo "ERROR: Garage S3 credentials are not yet written to infrastructure/garage/.env."
            echo "       Start Garage first:  cd ../../infrastructure/garage && ./start.sh"
            exit 1
        fi

        sed -i "s|^AWS_ACCESS_KEY_ID=.*|AWS_ACCESS_KEY_ID=${GARAGE_KEY_ID}|" .env
        sed -i "s|^AWS_SECRET_ACCESS_KEY=.*|AWS_SECRET_ACCESS_KEY=${GARAGE_SECRET}|" .env
        echo "S3 credentials populated from infrastructure/garage/.env."
    else
        echo ""
        echo "ERROR: infrastructure/garage/.env not found."
        echo "       Start Garage first:  cd ../../infrastructure/garage && ./start.sh"
        exit 1
    fi
fi

# ── Auth check ────────────────────────────────────────────────────────────────
HAS_AUTH=false
if grep -qE "^OIDC_CLIENT_SECRET=.+" .env 2>/dev/null; then HAS_AUTH=true; fi
if grep -qE "^SMTP_HOST=.+" .env 2>/dev/null; then HAS_AUTH=true; fi
if grep -qE "^(SLACK|GOOGLE|GITHUB)_CLIENT_ID=.+" .env 2>/dev/null; then HAS_AUTH=true; fi

if [[ "$HAS_AUTH" == "false" ]]; then
    echo ""
    echo "  ┌─────────────────────────────────────────────────────────────────┐"
    echo "  │  WARNING: No auth provider is configured.                       │"
    echo "  │  Users will not be able to sign in until you configure one.     │"
    echo "  │                                                                 │"
    echo "  │  Recommended: fill in OIDC_* vars in .env once Keycloak is     │"
    echo "  │  running, then restart: ./stop.sh && ./start.sh                 │"
    echo "  └─────────────────────────────────────────────────────────────────┘"
    echo ""
fi

# ── Pull and start ─────────────────────────────────────────────────────────────
echo "Pulling images..."
docker compose -p "$PROJECT" pull --quiet

echo "Starting services..."
docker compose -p "$PROJECT" up -d

# ── Garage bucket setup ────────────────────────────────────────────────────────
if docker inspect garage &>/dev/null 2>&1; then
    BUCKET=outline

    if ! docker exec garage /garage bucket info "$BUCKET" &>/dev/null 2>&1; then
        echo "Creating '$BUCKET' bucket in Garage..."
        docker exec garage /garage bucket create "$BUCKET"
    fi

    # Idempotent: re-applying allow is safe
    docker exec garage /garage bucket allow --read --write --owner "$BUCKET" --key default
    echo "  Garage bucket '$BUCKET' is ready."
else
    echo ""
    echo "  NOTE: Garage is not running — skipping bucket setup."
    echo "  Start Garage then run manually:"
    echo "    docker exec garage /garage bucket create outline"
    echo "    docker exec garage /garage bucket allow --read --write --owner outline --key default"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
APP_URL=$(grep "^URL=" .env | cut -d= -f2-)

echo ""
echo "Outline is starting. Allow 30–60 s for migrations on first run."
echo ""
echo "  UI:   ${APP_URL:-http://localhost:3000}"
echo ""
if [[ "$HAS_AUTH" == "false" ]]; then
    echo "  Next step: configure OIDC_* in .env (see README.md), then:"
    echo "    ./stop.sh && ./start.sh"
    echo ""
fi
echo "To tail logs:  docker compose -p $PROJECT logs -f"
