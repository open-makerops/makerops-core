#!/bin/bash
# Stops the cloudflare-ddns container.
set -e

PROJECT=cloudflare-ddns

docker compose -p "$PROJECT" down "$@"
