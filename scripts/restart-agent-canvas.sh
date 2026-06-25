#!/usr/bin/env bash
# Recover when agent-server :18000 stops responding (UI shows Disconnected).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT/.env}"
COMPOSE="docker compose --env-file $ENV_FILE -f $ROOT/deploy/docker-compose.yml"
WAIT_SEC="${WAIT_SEC:-120}"

probe_18000() {
  docker exec agent-canvas wget -qO- --timeout=5 http://127.0.0.1:18000/health >/dev/null 2>&1
}

echo "==> Current state"
docker ps --filter name=agent-canvas --format 'table {{.Names}}\t{{.Status}}' || true

if docker ps --format '{{.Names}}' | grep -qx agent-canvas; then
  echo ""
  echo "==> Processes listening (inside container)"
  docker exec agent-canvas sh -c 'ss -lntp 2>/dev/null | grep -E "18000|18001|8000" || netstat -lntp 2>/dev/null | grep -E "18000|18001|8000" || true' || true

  echo ""
  echo "==> Memory"
  docker exec agent-canvas sh -c 'free -h 2>/dev/null || true' || true
  free -h 2>/dev/null || true

  echo ""
  echo "==> Quick probe :18000/health (5s timeout)"
  if probe_18000; then
    echo "OK — agent-server already responding; no restart needed."
    exit 0
  fi
  echo "FAIL — :18000 not responding"
fi

echo ""
echo "==> Restarting agent-canvas (orchestrator stays up)..."
$COMPOSE stop agent-canvas 2>/dev/null || true
docker rm -f agent-canvas 2>/dev/null || true
$COMPOSE up -d --force-recreate agent-canvas

echo "==> Waiting up to ${WAIT_SEC}s for :18000/health..."
deadline=$((SECONDS + WAIT_SEC))
while [ "$SECONDS" -lt "$deadline" ]; do
  if probe_18000; then
    echo "OK — agent-server healthy on :18000"
    if docker exec agent-canvas test -x /home/openhands/.local/bin/agent 2>/dev/null; then
      echo "OK — cursor CLI at /home/openhands/.local/bin/agent"
    else
      echo "WARN — cursor CLI missing; run: bash scripts/setup-cursor-acp.sh"
      echo "      ACP command must be /home/openhands/.local/bin/agent (not 'agent')"
    fi
    curl -fsS --connect-timeout 5 http://127.0.0.1:8000/health >/dev/null && echo "OK — proxy :8000/health"
    IP="$(bash "$ROOT/scripts/public-ip.sh" 2>/dev/null || echo 127.0.0.1)"
    echo ""
    echo "Reload browser: http://${IP}:8000/ → Manage Backends → Save"
    exit 0
  fi
  sleep 5
  echo "  ... still waiting ($((deadline - SECONDS))s left)"
done

echo ""
echo "ERROR: :18000 still not responding after restart."
echo "Next steps:"
echo "  docker logs agent-canvas --tail 80"
echo "  bash scripts/fix-agent-canvas-volumes.sh"
echo "  bash scripts/reset-agent-canvas.sh   # wipes local Canvas state"
exit 1
