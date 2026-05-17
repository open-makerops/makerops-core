#!/bin/bash
# Stops the Ollama container. The ollama_data volume (all downloaded models) is preserved.
# Pass --volumes to also remove the ollama_data volume (destructive — models must be re-pulled).
set -e

PROJECT=ollama

docker compose -p "$PROJECT" down "$@"
