#!/bin/bash
# Starts the BookStack wiki stack.
#
# First run:  auto-generates APP_KEY and writes it into .env,
#             then pulls images and starts services.
# Subsequent runs: APP_KEY already exists — skips generation and starts.
set -e

PROJECT=bookstack
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ── Generate APP_KEY on first run ─────────────────────────────────────────────
if grep -q "^APP_KEY=$" .env 2>/dev/null; then
    echo "Generating APP_KEY..."
    APP_KEY="base64:$(openssl rand -base64 32)"
    sed -i "s|^APP_KEY=$|APP_KEY=${APP_KEY}|" .env
    echo "  Generated APP_KEY."
fi

# ── Pull and start ─────────────────────────────────────────────────────────────
echo "Pulling images..."
docker compose -p "$PROJECT" pull --quiet

echo "Starting services..."
docker compose -p "$PROJECT" up -d

# ── Summary ───────────────────────────────────────────────────────────────────
APP_URL=$(grep "^APP_URL=" .env | cut -d= -f2-)
echo ""
echo "BookStack is starting. Allow 30–60 s for the database to seed on first run."
echo ""
echo "  UI:              ${APP_URL:-http://localhost:6875}"
echo "  Default login:   admin@admin.com / password"
echo ""
echo "To tail logs:  docker compose -p $PROJECT logs -f"
