#!/bin/bash
# Starts the Ollama LLM inference server.
# On first run, pull a model after startup:
#   docker exec ollama ollama pull llama3.2
set -e

PROJECT=ollama

echo "Pulling latest image..."
docker compose -p "$PROJECT" pull

echo "Starting services..."
docker compose -p "$PROJECT" up -d

echo ""
echo "Ollama is starting. Ready in ~10 seconds."
echo ""
echo "API:  http://localhost:11434"
echo ""
echo "Pull a model on first run:"
echo "  docker exec ollama ollama pull llama3.2"
echo ""
echo "To watch startup: docker compose -p $PROJECT logs -f ollama"
