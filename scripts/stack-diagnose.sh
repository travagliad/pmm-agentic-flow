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
echo "==> curl agent-canvas"
curl -fsS --connect-timeout 5 "http://127.0.0.1:8000/" | head -c 120 || echo "FAIL"

echo ""
echo "==> curl orchestrator health"
curl -fsS --connect-timeout 5 "http://127.0.0.1:8080/orchestrator/health" || echo "FAIL"

echo ""
echo "==> agent-canvas (last 20 lines)"
docker logs agent-canvas --tail 20 2>&1 || true

echo ""
echo "==> orchestrator (last 15 lines)"
docker logs orchestrator --tail 15 2>&1 || true
