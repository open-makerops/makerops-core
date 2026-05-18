#!/bin/bash
# Stops all Outline services. Data in ./data is preserved.
# Pass --volumes to also remove any named volumes (bind mounts are unaffected).
set -e

PROJECT=outline

docker compose -p "$PROJECT" down "$@"
