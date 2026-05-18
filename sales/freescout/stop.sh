#!/bin/bash
# Stops all FreeScout services. Data volumes are preserved.
# Pass --volumes to also remove db_data, app_data, app_logs (destructive).
set -e

PROJECT=freescout

docker compose -p "$PROJECT" down "$@"
