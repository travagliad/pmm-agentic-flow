#!/usr/bin/env bash
# Run ON THE LINODE as root: bash scripts/stack-diagnose.sh
set -euo pipefail

DEST="${DEST:-/opt/pmm-agentic-flow/src}"
ENV_FILE="${ENV_FILE:-$DEST/.env}"
COMPOSE="docker compose --env-file $ENV_FILE -f $DEST/deploy/docker-compose.yml"

echo "==> Expected: agent-canvas, orchestrator (2 running)"
$COMPOSE ps -a

IP="$(bash "$DEST/scripts/public-ip.sh" 2>/dev/null || echo '?')"
echo ""
echo "==> URLs"
echo "    Canvas: http://$IP:8000/"
echo "    Webhook: http://$IP:8080/hooks/jira"

echo ""
echo "==> External access (Cloud Firewall — not ufw)"
echo "    If browser cannot reach :8000, run: bash scripts/open-linode-firewall.sh"

echo ""
echo "==> curl agent-canvas (localhost — if FAIL, not a Linode firewall issue)"
curl -fsS --connect-timeout 5 "http://127.0.0.1:8000/" | head -c 120 || echo "FAIL — check: docker logs agent-canvas"

echo ""
echo "==> curl orchestrator health"
curl -fsS --connect-timeout 5 "http://127.0.0.1:8080/orchestrator/health" || echo "FAIL"

echo ""
echo "==> agent-server :18000 (inside container)"
if docker exec agent-canvas wget -qO- --timeout=8 http://127.0.0.1:18000/health 2>/dev/null | head -c 200; then
  echo ""
  echo "OK — agent-server healthy"
else
  echo "FAIL — agent-server not running (Manage Backends will show Disconnected)"
fi

echo ""
echo "==> proxy :8000/health"
curl -fsS --connect-timeout 8 "http://127.0.0.1:8000/health" && echo "" || echo "FAIL — frontend proxy health"

echo ""
echo "==> docker health status"
docker inspect agent-canvas --format 'health={{.State.Health.Status}}' 2>/dev/null || true

echo ""
echo "==> orchestrator (last 15 lines)"
docker logs orchestrator --tail 15 2>&1 || true
