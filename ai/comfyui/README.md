# ComfyUI

Node-based workflow UI for generative AI image creation. This service uses the [ai-dock/comfyui](https://github.com/ai-dock/comfyui) Docker image, which packages ComfyUI with a built-in service portal, process management, and a provisioning system for downloading models on first run.

The default foundation model is **FLUX.1**:

- **FLUX.1-dev** — higher quality, requires a Hugging Face token and license acceptance
- **FLUX.1-schnell** — faster, no token required (automatic fallback without `HF_TOKEN`)

## Prerequisites

Before starting, install the NVIDIA Container Toolkit on the host. See [ai/README.md](../README.md#-prerequisite-nvidia-container-toolkit) for the installation link and verification steps.

## Attribution

**ComfyUI** is open-source software developed and maintained by [comfyanonymous](https://github.com/comfyanonymous) and contributors, made freely available under the [GNU GPL v3 License](https://github.com/comfyanonymous/ComfyUI/blob/master/LICENSE).

**ai-dock/comfyui** Docker packaging is developed and maintained by the [ai-dock contributors](https://github.com/ai-dock/comfyui/graphs/contributors), made freely available under the [MIT License](https://github.com/ai-dock/comfyui/blob/main/LICENSE).

**FLUX.1** models are developed by [Black Forest Labs](https://blackforestlabs.ai). FLUX.1-dev is available under the [FLUX.1-dev Non-Commercial License](https://huggingface.co/black-forest-labs/FLUX.1-dev/blob/main/LICENSE.md). FLUX.1-schnell is available under the [Apache 2.0 License](https://huggingface.co/black-forest-labs/FLUX.1-schnell/blob/main/LICENSE.md).

## Ports

| Port | Purpose |
| ---- | ------- |
| [8188](http://localhost:8188) | ComfyUI web interface |
| [1111](http://localhost:1111) | ai-dock service portal (logs, process control, system info) |

## First-Run Setup

1. **Set your Hugging Face token** (optional, for FLUX.1-dev):
   - Create a token at [huggingface.co/settings/tokens](https://huggingface.co/settings/tokens)
   - Accept the FLUX.1-dev model license at [huggingface.co/black-forest-labs/FLUX.1-dev](https://huggingface.co/black-forest-labs/FLUX.1-dev)
   - Set `HF_TOKEN=<your-token>` in `.env`
   - Without a token, FLUX.1-schnell is downloaded automatically (no license required)

2. **Run the service:**

   ```bash
   ./start.sh
   ```

   On the very first run, `start.sh` will create `.env` from `.env.example` and exit, prompting you to set `HF_TOKEN`. Run it again after editing `.env`.

3. **Wait for provisioning to complete:**
   On first container start, the provisioning script downloads FLUX models (~25 GB total). This takes 10–30 minutes depending on your connection. Watch progress:

   ```bash
   docker compose -p comfyui logs -f comfyui
   ```

   ComfyUI becomes accessible once provisioning finishes and the process starts.

   `start.sh` automatically disables provisioning after the first successful start by writing a `.provisioned` sentinel file and clearing `PROVISIONING_SCRIPT` from `.env`. Subsequent starts skip provisioning and launch immediately.

   To re-run provisioning (e.g. to pull updated models): delete `.provisioned` and restore the `PROVISIONING_SCRIPT` URL in `.env`, then run `start.sh` again.

## Model Storage

All persistent data — models, generated outputs, custom nodes, and configuration — is stored in the workspace volume at `./data/workspace` (or the path set in `COMFYUI_WORKSPACE_PATH`).

FLUX models are large. The workspace will be approximately 25 GB after first provisioning. If disk space is a concern, set `COMFYUI_WORKSPACE_PATH` in `.env` to an absolute path on a larger volume before starting.
