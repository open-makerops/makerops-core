# ollama — Local LLM Inference Server

Ollama runs open-weight language models locally via a REST API. It manages model downloads, GPU scheduling, and request serving behind a single interface compatible with most LLM client libraries.

- **Home page / docs:** <https://ollama.com>
- **GitHub:** <https://github.com/ollama/ollama>
- **Docker image:** `ollama/ollama`
- **Model library:** <https://ollama.com/library>

---

## Attribution

**Ollama** is open-source software developed and maintained by the [Ollama contributors](https://github.com/ollama/ollama/graphs/contributors), made freely available under the [MIT License](https://github.com/ollama/ollama/blob/main/LICENSE).

---

## Prerequisites

The NVIDIA Container Toolkit must be installed and configured on the host before running this service. See [ai/README.md](../README.md) for the prerequisite link and installation guidance.

---

## Local Access

| | |
| --- | --- |
| **API endpoint** | <http://localhost:11434> |

---

## Setup

### Before first start

No `.env` configuration is required. Ollama runs with its defaults out of the box.

### Start

```bash
./start.sh
```

### Pull your first model

After the container is running, pull a model from the [Ollama library](https://ollama.com/library):

```bash
# Small, fast — good for general use and integration testing
docker exec ollama ollama pull llama3.2

# Larger, more capable — requires more VRAM
docker exec ollama ollama pull llama3.3
```

Models are stored in the `ollama_ollama_data` Docker volume and persist across container restarts. Each model is downloaded once.

---

## Scripts

### `./start.sh`

Pulls the latest image and starts the container.

```bash
./start.sh
```

### `./stop.sh`

Stops the container. The `ollama_data` volume (all downloaded models) is preserved.

```bash
./stop.sh
```

### `./teardown.sh`

Interactive full teardown: shows what will be removed, prompts for confirmation, then deletes the container, volume, image, and network. **All downloaded models will be deleted** — they must be re-pulled after a fresh start.

```bash
./teardown.sh
```

---

## Files

| File | Purpose |
| --- | --- |
| `docker-compose.yml` | Single-container stack definition with GPU reservation |
| `start.sh` | Pull image and start |
| `stop.sh` | Stop (volume preserved) |
| `teardown.sh` | Full wipe with confirmation |

---

## Architecture

```text
LLM clients / n8n / applications
  └─► localhost:11434  (TCP) → Ollama REST API
          └─► ollama  (ollama/ollama:latest)
                ├─► NVIDIA GPU  (via NVIDIA Container Toolkit)
                └─► ollama_data volume  (/root/.ollama — model weights)
```

---

## Cheat Sheet

### Logs

```bash
docker compose -p ollama logs -f
docker logs ollama -f
```

### Shell access

```bash
docker exec -it ollama bash
```

### List downloaded models

```bash
docker exec ollama ollama list
```

### Run a model interactively

```bash
docker exec -it ollama ollama run llama3.2
```

### Delete a model

```bash
docker exec ollama ollama rm llama3.2
```

### Check GPU usage

```bash
docker exec ollama nvidia-smi
```

### Backup models

The entire model store lives in the `ollama_ollama_data` Docker volume. Back it up with:

```bash
docker run --rm -v ollama_ollama_data:/data -v $(pwd):/backup alpine \
  tar czf /backup/ollama-backup.tar.gz -C /data .
```

### Upgrade

1. `./stop.sh`
2. `docker pull ollama/ollama:latest`
3. `./start.sh` — existing models in the volume are preserved

### API usage

```bash
# Check server health
curl http://localhost:11434

# Generate a completion
curl http://localhost:11434/api/generate -d '{
  "model": "llama3.2",
  "prompt": "Why is the sky blue?",
  "stream": false
}'

# List available models
curl http://localhost:11434/api/tags
```
