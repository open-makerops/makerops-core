#!/bin/bash
# Starts all docker application stacks in manufacturing_tools subdirectories.
# Each service's start.sh is run from within its own directory so that
# relative .env and volume paths resolve correctly.
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SERVICES=(
    bookstack
    n8n
    freescout
    invoiceninja
    inventree
    plane
    triggerdev
)

FAILED=()

for SERVICE in "${SERVICES[@]}"; do
    DIR="$SCRIPT_DIR/$SERVICE"

    if [ ! -f "$DIR/start.sh" ]; then
        echo "⚠  $SERVICE: no start.sh found — skipping"
        continue
    fi

    echo "──────────────────────────────────────────"
    echo "▶  Starting $SERVICE..."
    echo "──────────────────────────────────────────"

    if (cd "$DIR" && bash start.sh); then
        echo "✔  $SERVICE started"
    else
        echo "✘  $SERVICE failed to start"
        FAILED+=("$SERVICE")
    fi

    echo ""
done

echo "══════════════════════════════════════════"
if [ ${#FAILED[@]} -eq 0 ]; then
    echo "All services started successfully."
else
    echo "The following services failed to start:"
    for F in "${FAILED[@]}"; do
        echo "  - $F"
    done
    exit 1
fi
