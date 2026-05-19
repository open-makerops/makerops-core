#!/bin/bash
# Starts the n8n workflow automation stack.
# Auto-generates N8N_ENCRYPTION_KEY and RUNNERS_AUTH_TOKEN on first run.
# On subsequent runs the database and volumes already exist — n8n resumes.
set -e

PROJECT=n8n

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ── Auto-generate secrets on first run ────────────────────────────────────────
if grep -q "^N8N_ENCRYPTION_KEY=OVERWRITE_ME" .env 2>/dev/null; then
    echo "Generating N8N_ENCRYPTION_KEY..."
    KEY=$(openssl rand -hex 32)
    sed -i "s|^N8N_ENCRYPTION_KEY=OVERWRITE_ME|N8N_ENCRYPTION_KEY=${KEY}|" .env
    echo "N8N_ENCRYPTION_KEY saved to .env"
fi

if grep -q "^RUNNERS_AUTH_TOKEN=OVERWRITE_ME" .env 2>/dev/null; then
    echo "Generating RUNNERS_AUTH_TOKEN..."
    TOKEN=$(openssl rand -hex 24)
    sed -i "s|^RUNNERS_AUTH_TOKEN=OVERWRITE_ME|RUNNERS_AUTH_TOKEN=${TOKEN}|" .env
    echo "RUNNERS_AUTH_TOKEN saved to .env"
fi

# ── Ensure n8n data directory is writable by the node user (UID 1000) ─────────
# Docker Compose creates missing bind-mount host directories as root:root.
# n8n runs as the node user (UID 1000) and cannot write to a root-owned dir.
# Pre-creating the directory here prevents Docker from claiming it as root.
# If it already exists with wrong ownership (e.g. from a prior run), fix it
# via Docker so no sudo is required.
N8N_DATA="$(grep '^N8N_APP_DATA_PATH=' .env 2>/dev/null | cut -d= -f2- | tr -d '[:space:]')"
N8N_DATA="${N8N_DATA:-./data/n8n}"

mkdir -p "$N8N_DATA"

if [[ "$(stat -c '%u' "$N8N_DATA")" != "1000" ]]; then
    echo "Fixing ownership of $N8N_DATA for n8n container (UID 1000)..."
    docker run --rm \
        -v "$(cd "$N8N_DATA" && pwd)":/target \
        alpine \
        chown 1000:1000 /target
fi

# ── Pull and start ─────────────────────────────────────────────────────────────
echo "Pulling latest images..."
docker compose -p "$PROJECT" pull

echo "Starting services..."
docker compose -p "$PROJECT" up -d

echo ""
echo "n8n is starting. Ready in ~30 seconds."
echo ""
echo "UI:     http://localhost:${N8N_PORT_HOST:-5678}"
echo "Login:  create your owner account on first visit"
echo ""
echo "To watch startup: docker compose -p $PROJECT logs -f n8n"
