#!/bin/bash
# Stops all InvenTree services. Data volumes are preserved.
# Pass --volumes to also remove all volumes (destructive — data loss).
set -e

PROJECT=inventree

docker compose -p "$PROJECT" down "$@"
