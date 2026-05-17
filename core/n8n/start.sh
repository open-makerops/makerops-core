#!/bin/bash
# Starts the n8n workflow automation stack.
# Auto-generates N8N_ENCRYPTION_KEY and RUNNERS_AUTH_TOKEN on first run.
# On subsequent runs the database and volumes already exist — n8n resumes.
set -e

PROJECT=n8n

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
