#!/bin/bash
# Starts the wg-easy WireGuard VPN stack.
#
# First run:  ensure INIT_ENABLED=true and all INIT_* vars are set in .env,
#             then run this script to bootstrap the admin account and WireGuard
#             config. Set INIT_ENABLED=false after the first successful start.
# Subsequent runs: config is persisted to the Docker volume; just starts up.
set -e

PROJECT=wg-easy
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ── Warn if INIT_PASSWORD is still the placeholder ────────────────────────────
if grep -q "^INIT_PASSWORD=CHANGE_ME" .env 2>/dev/null && \
   grep -q "^INIT_ENABLED=true" .env 2>/dev/null; then
    echo "WARNING: INIT_PASSWORD is still set to CHANGE_ME in .env."
    echo "         Update it to a real password before first run."
    exit 1
fi

if grep -q "^INIT_HOST=CHANGE_ME" .env 2>/dev/null && \
   grep -q "^INIT_ENABLED=true" .env 2>/dev/null; then
    echo "WARNING: INIT_HOST is still set to CHANGE_ME in .env."
    echo "         Set it to the public IP or hostname VPN clients will connect to."
    exit 1
fi

# ── Pull and start ─────────────────────────────────────────────────────────────
echo "Pulling latest image..."
docker compose -p "$PROJECT" pull --quiet

echo "Starting services..."
docker compose -p "$PROJECT" up -d

WG_UI_PORT=$(grep "^WG_UI_PORT=" .env | cut -d= -f2-)
WG_UDP_PORT=$(grep "^WG_UDP_PORT=" .env | cut -d= -f2-)

echo ""
echo "wg-easy is starting."
echo ""
echo "  Web UI:     http://localhost:${WG_UI_PORT:-51821}"
echo "  VPN port:   UDP ${WG_UDP_PORT:-51820}"
echo ""
echo "To watch logs:  docker compose -p $PROJECT logs -f"
