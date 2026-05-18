#!/bin/bash
# Stops all BookStack services. Data in ./config and ./db_data is preserved.
# Pass --volumes to also remove any named volumes (bind mounts are unaffected).
set -e

PROJECT=bookstack

docker compose -p "$PROJECT" down "$@"
