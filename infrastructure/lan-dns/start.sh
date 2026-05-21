#!/bin/bash
set -e

PROJECT=lan-dns

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [[ ! -f .env ]]; then
    cp .env.example .env
    echo ".env created from .env.example — set HOST_NAME, HOST_LAN_IP, and LAN_TLD before continuing."
    echo "Then re-run: ./start.sh"
    exit 0
fi

source .env

# Validate required variables.
for var in HOST_NAME HOST_LAN_IP LAN_TLD; do
    val="${!var}"
    if [[ -z "$val" ]]; then
        echo "Error: $var is not set in .env"
        exit 1
    fi
done

# Warn on unsafe TLD choices.
if [[ "${LAN_TLD}" == "local" ]]; then
    echo "Warning: LAN_TLD=local conflicts with mDNS/Bonjour (.local is reserved)."
    echo "Use a different TLD such as 'lan', 'home', or 'internal'."
    echo "Edit .env and re-run to change it."
    exit 1
fi

# Generate dnsmasq.conf from template.
envsubst '${HOST_NAME} ${LAN_TLD} ${HOST_LAN_IP} ${UPSTREAM_DNS_1} ${UPSTREAM_DNS_2}' \
    < dnsmasq.conf.template \
    > dnsmasq.conf

echo "Building image..."
docker compose -p "$PROJECT" build --quiet

echo "Starting lan-dns..."
docker compose -p "$PROJECT" up -d

echo ""
echo "lan-dns is running on port ${DNS_PORT:-53}."
echo ""
echo "  Resolves: *.${HOST_NAME}.${LAN_TLD} → ${HOST_LAN_IP}"
echo "  Example:  n8n.${HOST_NAME}.${LAN_TLD}"
echo "            outline.${HOST_NAME}.${LAN_TLD}"
echo ""
echo "Next steps:"
echo "  1. Open port 53 on this host's firewall (see README — Firewall Setup)."
echo "  2. Point LAN clients at ${HOST_LAN_IP} as their DNS server (see README — Client Setup)."
echo "  3. Start name-proxy (infrastructure/name-proxy/start.sh) if not already running."
echo ""
echo "Verify: dig @${HOST_LAN_IP} n8n.${HOST_NAME}.${LAN_TLD}"
echo "To tail logs: docker compose -p $PROJECT logs -f"
