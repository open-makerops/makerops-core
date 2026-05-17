#!/bin/bash
# Stops the ComfyUI container. The workspace volume (models, outputs, configs) is preserved.
# Pass --volumes to also remove the workspace volume (destructive — models must be re-downloaded).
set -e

PROJECT=comfyui

docker compose -p "$PROJECT" down "$@"
