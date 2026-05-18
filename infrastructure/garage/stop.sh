#!/bin/bash
# Stops all Garage services. Data in ./data is preserved.
# Pass --volumes to also remove any named volumes (bind mounts are unaffected).
set -e

PROJECT=garage

docker compose -p "$PROJECT" down "$@"
