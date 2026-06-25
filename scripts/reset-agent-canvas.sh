#!/usr/bin/env bash
# Wipe and recreate Agent Canvas state volume (fixes permission / SQLite corruption).
# Safe for POC — you lose Canvas settings/conversations stored on this VM only.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT/.env}"
IMAGE="${AGENT_CANVAS_IMAGE:-ghcr.io/openhands/agent-canvas:${AGENT_CANVAS_VERSION:-latest}}"
COMPOSE="docker compose --env-file $ENV_FILE -f $ROOT/deploy/docker-compose.yml"
VOL="agentic-flow_agent-canvas-state"

echo "==> Stopping services that use the canvas volume..."
$COMPOSE stop agent-canvas agent-canvas-init 2>/dev/null || true
$COMPOSE rm -f agent-canvas agent-canvas-init 2>/dev/null || true
docker rm -f agent-canvas 2>/dev/null || true

echo "==> Removing containers still attached to $VOL..."
while read -r cid; do
  [ -n "$cid" ] && docker rm -f "$cid"
done < <(docker ps -aq --filter "volume=$VOL" 2>/dev/null || true)

if docker volume inspect "$VOL" >/dev/null 2>&1; then
  echo "==> Removing volume $VOL"
  docker volume rm "$VOL"
fi

echo "==> Initializing fresh volume (openhands uid from image)..."
$COMPOSE run --rm --no-TTY agent-canvas-init

echo "==> Verifying write access as openhands..."
docker run --rm --user openhands --entrypoint /bin/sh \
  -v "${VOL}:/home/openhands/.openhands" \
  "$IMAGE" \
  -ec '
    touch /home/openhands/.openhands/agent-canvas/conversations/.write-test
    rm -f /home/openhands/.openhands/agent-canvas/conversations/.write-test
    echo "volume write OK"
  '

echo "==> Starting agent-canvas..."
$COMPOSE up -d --force-recreate agent-canvas

echo "==> Waiting for :8000 (up to 120s)..."
for i in $(seq 1 24); do
  if curl -fsS --connect-timeout 3 http://127.0.0.1:8000/ >/dev/null 2>&1; then
    echo "agent-canvas OK — http://$(curl -4 -fsSL https://ifconfig.me/ip 2>/dev/null || echo 127.0.0.1):8000/"
    exit 0
  fi
  sleep 5
done

echo "Still not up — check: docker logs agent-canvas --tail 40"
exit 1
