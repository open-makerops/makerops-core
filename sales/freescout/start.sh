#!/bin/bash
# Starts the FreeScout help desk stack.
# On first run the application auto-installs and seeds the database (~2-5 minutes).
# On subsequent runs it detects existing data and starts normally.
set -e

PROJECT=freescout

echo "Pulling latest images..."
docker compose -p "$PROJECT" pull

echo "Starting services..."
docker compose -p "$PROJECT" up -d

echo ""
echo "FreeScout is starting. Database setup runs on first boot (~2-5 minutes)."
echo ""
echo "UI:     http://localhost:${FREESCOUT_PORT:-8095}"
echo "Login:  see ADMIN_EMAIL / ADMIN_PASS in .env  (change immediately)"
echo ""
echo "To watch startup: docker compose -p $PROJECT logs -f freescout"
