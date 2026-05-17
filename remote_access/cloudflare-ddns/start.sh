#!/bin/bash
# Starts the cloudflare-ddns stack.
#
# Requires a .env file with at minimum:
#   CLOUDFLARE_API_TOKEN — Cloudflare API token with Zone:DNS:Edit permission
#   DOMAINS              — comma-separated list of domains to keep updated
set -e

PROJECT=cloudflare-ddns
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ── Validate required variables ────────────────────────────────────────────────
if [[ ! -f .env ]]; then
    echo "ERROR: .env file not found."
    echo "       Copy the template and fill in CLOUDFLARE_API_TOKEN and DOMAINS."
    exit 1
fi

TOKEN=$(grep "^CLOUDFLARE_API_TOKEN=" .env | cut -d= -f2-)
if [[ -z "$TOKEN" || "$TOKEN" == "CHANGE_ME" ]]; then
    echo "ERROR: CLOUDFLARE_API_TOKEN is not set in .env."
    echo "       Create a token at https://dash.cloudflare.com/profile/api-tokens"
    echo "       with Zone:DNS:Edit permission."
    exit 1
fi

DOMAINS_VAL=$(grep "^DOMAINS=" .env | cut -d= -f2-)
IP4_VAL=$(grep "^IP4_DOMAINS=" .env | cut -d= -f2-)
IP6_VAL=$(grep "^IP6_DOMAINS=" .env | cut -d= -f2-)
if [[ -z "$DOMAINS_VAL" && -z "$IP4_VAL" && -z "$IP6_VAL" ]]; then
    echo "ERROR: No domains configured in .env."
    echo "       Set DOMAINS (or IP4_DOMAINS / IP6_DOMAINS) to the domains you want updated."
    exit 1
fi

# ── Pull and start ─────────────────────────────────────────────────────────────
echo "Pulling latest image..."
docker compose -p "$PROJECT" pull --quiet

echo "Starting services..."
docker compose -p "$PROJECT" up -d

echo ""
echo "cloudflare-ddns is running."
echo ""
echo "To watch logs:  docker compose -p $PROJECT logs -f"
