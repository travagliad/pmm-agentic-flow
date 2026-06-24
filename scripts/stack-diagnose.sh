#!/usr/bin/env bash
# Run ON THE LINODE as root: bash scripts/stack-diagnose.sh
set -euo pipefail

DEST="${DEST:-/opt/pmm-agentic-flow/src}"
ENV_FILE="${ENV_FILE:-$DEST/.env}"
COMPOSE="docker compose --env-file $ENV_FILE -f $DEST/deploy/docker-compose.yml"

echo "==> Stack status"
$COMPOSE ps -a

echo ""
echo "==> Env (domain + agent canvas)"
grep -E '^(LOOP_DOMAIN|AGENT_CANVAS_|OPENHANDS_)' "$ENV_FILE" 2>/dev/null || true

echo ""
echo "==> Host ports"
ss -tlnp | grep -E ':8000|:4000|:8080|:443 ' || true

echo ""
echo "==> Caddy -> orchestrator /loop/health"
docker exec loop-caddy wget -qO- --timeout=5 http://orchestrator:8080/health 2>&1 || echo "FAIL"

echo ""
echo "==> Caddy -> agent-canvas:8000"
docker exec loop-caddy wget -qO- --timeout=5 http://agent-canvas:8000/ 2>&1 | head -c 200 || echo "FAIL (502 in browser = this)"

echo ""
echo "==> loop-litellm (last 25 lines)"
docker logs loop-litellm --tail 25 2>&1 || true

echo ""
echo "==> loop-agent-canvas (last 50 lines)"
docker logs loop-agent-canvas --tail 50 2>&1 || true

echo ""
echo "==> loop-caddy (last 15 lines)"
docker logs loop-caddy --tail 15 2>&1 || true
