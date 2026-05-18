#!/bin/bash
# Stops all trigger.dev services. Data volumes are preserved.
# Pass --volumes to also remove all volumes (destructive — data loss).
set -e

PROJECT=triggerdev

docker compose -p "$PROJECT" down "$@"
