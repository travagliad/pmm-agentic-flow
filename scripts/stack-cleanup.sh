#!/usr/bin/env bash
# Remove legacy containers from older compose files (openhands 0.39, litellm, loop-* names).
set -euo pipefail

LEGACY=(
  loop-litellm loop-openhands loop-openhands-init loop-agent-canvas-init
  loop-agent-canvas loop-orchestrator loop-caddy
)

echo "==> Stopping legacy containers..."
for name in "${LEGACY[@]}"; do
  docker rm -f "$name" 2>/dev/null && echo "  removed $name" || true
done

DEST="${DEST:-/opt/pmm-agentic-flow/src}"
if [ -f "$DEST/deploy/docker-compose.yml" ]; then
  echo "==> docker compose down --remove-orphans"
  docker compose --env-file "${ENV_FILE:-$DEST/.env}" -f "$DEST/deploy/docker-compose.yml" down --remove-orphans 2>/dev/null || true
fi

echo "==> Done. Remaining containers:"
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'
