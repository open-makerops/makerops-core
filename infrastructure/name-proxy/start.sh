#!/bin/bash
set -e

PROJECT=name-proxy

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [[ ! -f .env ]]; then
    cp .env.example .env
    echo ".env created from .env.example — edit if you've changed any service ports."
fi

source .env

echo "Pulling latest image..."
docker compose -p "$PROJECT" pull --quiet

echo "Starting name-proxy..."
docker compose -p "$PROJECT" up -d

echo ""
echo "name-proxy is running on port ${PROXY_PORT:-80}."
echo ""
echo "  http://root.localhost         → home page"
echo "  http://n8n.localhost          → port ${N8N_PORT:-5678}"
echo "  http://outline.localhost      → port ${OUTLINE_PORT:-3000}"
echo "  http://plane.localhost        → port ${PLANE_PORT:-8100}"
echo "  http://trigger.localhost      → port ${TRIGGERDEV_PORT:-3040}"
echo "  http://freescout.localhost    → port ${FREESCOUT_PORT:-8095}"
echo "  http://invoiceninja.localhost → port ${INVOICENINJA_PORT:-8092}"
echo "  http://inventree.localhost    → port ${INVENTREE_PORT:-8096}"
echo "  http://ollama.localhost       → port ${OLLAMA_PORT:-11434}"
echo "  http://comfyui.localhost      → port ${COMFYUI_PORT:-8188}"
echo "  http://wg.localhost           → port ${WG_PORT:-8820}"
echo ""
echo "To tail logs: docker compose -p $PROJECT logs -f"
