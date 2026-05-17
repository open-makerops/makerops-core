#!/bin/bash
# Stops all docker application stacks in manufacturing_tools subdirectories.
# Services are stopped in reverse start order to respect dependencies.
# Any arguments (e.g. --volumes) are passed through to every stop.sh.
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Reverse of start order
SERVICES=(
    triggerdev
    plane
    inventree
    invoiceninja
    freescout
    n8n
    bookstack
)

FAILED=()

for SERVICE in "${SERVICES[@]}"; do
    DIR="$SCRIPT_DIR/$SERVICE"

    if [ ! -f "$DIR/stop.sh" ]; then
        echo "⚠  $SERVICE: no stop.sh found — skipping"
        continue
    fi

    echo "──────────────────────────────────────────"
    echo "■  Stopping $SERVICE..."
    echo "──────────────────────────────────────────"

    if (cd "$DIR" && bash stop.sh "$@"); then
        echo "✔  $SERVICE stopped"
    else
        echo "✘  $SERVICE failed to stop cleanly"
        FAILED+=("$SERVICE")
    fi

    echo ""
done

echo "══════════════════════════════════════════"
if [ ${#FAILED[@]} -eq 0 ]; then
    echo "All services stopped."
else
    echo "The following services did not stop cleanly:"
    for F in "${FAILED[@]}"; do
        echo "  - $F"
    done
    exit 1
fi
