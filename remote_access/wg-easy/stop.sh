#!/bin/bash
# Stops the wg-easy container. The wg_data volume is preserved.
# Pass --volumes to also remove the wg_data volume (destructive).
set -e

PROJECT=wg-easy

docker compose -p "$PROJECT" down "$@"
