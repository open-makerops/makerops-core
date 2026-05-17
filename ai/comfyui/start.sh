#!/bin/bash
# Starts the ComfyUI image generation service.
# On first run, the provisioning script downloads FLUX models (~25 GB).
# Watch progress with: docker compose -p comfyui logs -f comfyui
set -e

PROJECT=comfyui
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ── First-run: create .env from template ──────────────────────────────────────
if [ ! -f .env ]; then
    cp .env.example .env
    echo ""
    echo "Created .env from .env.example."
    echo ""
    echo "  ⚠ Before starting, open .env and set HF_TOKEN to your Hugging Face"
    echo "    token to enable FLUX.1-dev. Without it, FLUX.1-schnell will be"
    echo "    downloaded instead (no token or license required)."
    echo ""
    echo "Re-run start.sh when ready."
    exit 1
fi

# ── Secret generation ─────────────────────────────────────────────────────────
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

WEB_PASSWORD=$(generate_if_needed WEB_PASSWORD 16)
WEB_USER=$(grep "^WEB_USER=" .env | cut -d= -f2-)

# ── Provisioning state ────────────────────────────────────────────────────────
# After the first successful start, .provisioned is written and PROVISIONING_SCRIPT
# is automatically cleared so models are never re-downloaded on subsequent starts.
# To re-run provisioning: delete .provisioned and restore PROVISIONING_SCRIPT in .env.
if [ -f .provisioned ]; then
    if grep -q "^PROVISIONING_SCRIPT=.\+" .env 2>/dev/null; then
        sed -i 's|^PROVISIONING_SCRIPT=.\+|PROVISIONING_SCRIPT=|' .env
    fi
fi

# ── Start ─────────────────────────────────────────────────────────────────────
echo "Pulling latest image..."
docker compose -p "$PROJECT" pull

echo "Starting services..."
docker compose -p "$PROJECT" up -d

# Mark provisioning as complete after first successful start
if [ ! -f .provisioned ]; then
    touch .provisioned
fi

COMFYUI_PORT=$(grep "^COMFYUI_PORT_HOST=" .env | cut -d= -f2-)
COMFYUI_PORT=${COMFYUI_PORT:-8188}
SERVICEPORTAL_PORT=$(grep "^COMFYUI_SERVICEPORTAL_PORT_HOST=" .env | cut -d= -f2-)
SERVICEPORTAL_PORT=${SERVICEPORTAL_PORT:-1111}

echo ""
echo "ComfyUI is starting."
echo ""
echo "  UI:             http://localhost:${COMFYUI_PORT}"
echo "  Service Portal: http://localhost:${SERVICEPORTAL_PORT}"
echo ""
echo "  Web user:     ${WEB_USER}"
echo "  Web password: ${WEB_PASSWORD}"
echo ""

HF_TOKEN_SET=$(grep "^HF_TOKEN=" .env | cut -d= -f2-)
if [ -z "$HF_TOKEN_SET" ]; then
    echo "  Model: FLUX.1-schnell (HF_TOKEN not set — set it in .env for FLUX.1-dev)"
else
    echo "  Model: FLUX.1-dev (HF_TOKEN is set)"
fi

PROV_SCRIPT=$(grep "^PROVISIONING_SCRIPT=" .env | cut -d= -f2-)
if [ -n "$PROV_SCRIPT" ]; then
    echo ""
    echo "  Provisioning is active — FLUX models (~25 GB) are downloading."
    echo "  This takes 10–30 minutes. On next start, provisioning is skipped automatically."
    echo "  Watch progress: docker compose -p $PROJECT logs -f comfyui"
fi

echo ""
