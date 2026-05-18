#!/bin/bash
# Stops all Plane services. Data volumes are preserved.
# Pass --volumes to also remove all volumes (destructive — data loss).
set -e

PROJECT=plane

docker compose -p "$PROJECT" down "$@"
