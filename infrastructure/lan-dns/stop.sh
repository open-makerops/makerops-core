#!/bin/bash
set -e

PROJECT=lan-dns

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Stopping lan-dns..."
docker compose -p "$PROJECT" down

echo "lan-dns stopped."
