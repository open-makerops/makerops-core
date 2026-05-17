#!/bin/bash
# Stops all Invoice Ninja services. Data volumes are preserved.
# Pass --volumes to also remove all volumes (destructive — data loss).
set -e

PROJECT=invoiceninja

docker compose -p "$PROJECT" down "$@"
