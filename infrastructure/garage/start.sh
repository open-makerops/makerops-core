#!/bin/bash
# Starts the Garage S3 object store.
#
# First run:
#   - Generates rpc_secret, admin_token, and metrics_token and writes garage.toml
#   - Initializes the single-node cluster (layout assign + apply)
#   - Creates a default S3 key and writes its credentials into .env
# Subsequent runs:
#   - Skips all of the above and just starts the container
set -e

PROJECT=garage
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ── Bootstrap .env ────────────────────────────────────────────────────────────
if [[ ! -f .env ]]; then
    echo "Creating .env from .env.example..."
    cp .env.example .env
fi

# ── Bootstrap garage.toml ─────────────────────────────────────────────────────
if [[ ! -f garage.toml ]]; then
    echo "Generating garage.toml..."
    cp garage.toml.example garage.toml

    RPC_SECRET=$(openssl rand -hex 32)
    ADMIN_TOKEN=$(openssl rand -hex 32)
    METRICS_TOKEN=$(openssl rand -hex 32)

    # Replace each GENERATE_ME in order (one per sed pass to handle multiple matches)
    sed -i "0,/GENERATE_ME/s/GENERATE_ME/${RPC_SECRET}/" garage.toml
    sed -i "0,/GENERATE_ME/s/GENERATE_ME/${ADMIN_TOKEN}/" garage.toml
    sed -i "0,/GENERATE_ME/s/GENERATE_ME/${METRICS_TOKEN}/" garage.toml

    echo "  Generated rpc_secret, admin_token, and metrics_token."
fi

# ── Pull and start ─────────────────────────────────────────────────────────────
echo "Pulling images..."
docker compose -p "$PROJECT" pull --quiet

echo "Starting services..."
docker compose -p "$PROJECT" up -d

# ── Wait for healthy ──────────────────────────────────────────────────────────
echo "Waiting for Garage to become healthy..."
TIMEOUT=60
ELAPSED=0
until [[ "$(docker inspect --format '{{.State.Health.Status}}' garage 2>/dev/null)" == "healthy" ]]; do
    if [[ $ELAPSED -ge $TIMEOUT ]]; then
        echo "ERROR: Garage did not become healthy within ${TIMEOUT}s."
        echo "Check logs: docker compose -p $PROJECT logs garage"
        exit 1
    fi
    sleep 3
    ELAPSED=$((ELAPSED + 3))
done
echo "  Garage is healthy."

# ── Single-node cluster initialization ────────────────────────────────────────
SENTINEL="./.initialized"
if [[ ! -f "$SENTINEL" ]]; then
    echo "Initializing single-node cluster..."

    # Get the full node ID (hex string)
    NODE_ID=$(docker exec garage /garage node id 2>/dev/null | awk '{print $1}' | cut -d@ -f1)
    if [[ -z "$NODE_ID" ]]; then
        echo "ERROR: Could not retrieve node ID from Garage."
        exit 1
    fi
    echo "  Node ID: ${NODE_ID}"

    # Assign layout: zone dc1, capacity 1 GB (capacity is advisory for single-node)
    docker exec garage /garage layout assign -z dc1 -c 1G "$NODE_ID"

    # Apply layout at version 1
    docker exec garage /garage layout apply --version 1

    echo "  Cluster layout applied."

    # Create default S3 key
    KEY_OUTPUT=$(docker exec garage /garage key create default 2>&1)
    KEY_ID=$(echo "$KEY_OUTPUT" | grep -E "^Key ID:" | awk '{print $3}')
    KEY_SECRET=$(echo "$KEY_OUTPUT" | grep -E "^Secret key:" | awk '{print $3}')

    if [[ -z "$KEY_ID" || -z "$KEY_SECRET" ]]; then
        echo "ERROR: Could not parse key credentials from Garage output."
        echo "$KEY_OUTPUT"
        exit 1
    fi

    # Write credentials into .env
    sed -i "s|^GARAGE_ACCESS_KEY_ID=.*|GARAGE_ACCESS_KEY_ID=${KEY_ID}|" .env
    sed -i "s|^GARAGE_SECRET_ACCESS_KEY=.*|GARAGE_SECRET_ACCESS_KEY=${KEY_SECRET}|" .env

    # Write sentinel so we skip this block on subsequent starts
    touch "$SENTINEL"

    echo "  Default S3 key created and written to .env."
fi

# ── Summary ───────────────────────────────────────────────────────────────────
ACCESS_KEY_ID=$(grep "^GARAGE_ACCESS_KEY_ID=" .env | cut -d= -f2-)

echo ""
echo "Garage is running."
echo ""
echo "  S3 API:      http://localhost:3900"
echo "  Admin API:   http://localhost:3903"
echo "  S3 region:   garage"
echo "  Key ID:      ${ACCESS_KEY_ID:-  (see .env)}"
echo ""
echo "Check cluster status:  docker exec garage /garage status"
echo "To tail logs:          docker compose -p $PROJECT logs -f"
