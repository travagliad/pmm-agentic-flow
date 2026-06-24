#!/usr/bin/env bash
# Run ON THE LINODE as root: bash scripts/stack-diagnose.sh
set -euo pipefail

DEST="${DEST:-/opt/pmm-agentic-flow/src}"
ENV_FILE="${ENV_FILE:-$DEST/.env}"
COMPOSE="docker compose --env-file $ENV_FILE -f $DEST/deploy/docker-compose.yml"

echo "==> Stack status"
$COMPOSE ps -a

echo ""
echo "==> Env (domain + openhands version)"
grep -E '^(LOOP_DOMAIN|OPENHANDS_VERSION|AGENT_SERVER)' "$ENV_FILE" 2>/dev/null || true

echo ""
echo "==> Host ports"
ss -tlnp | grep -E ':3000|:4000|:8080|:443 ' || true

echo ""
echo "==> Caddy -> orchestrator /health"
docker exec loop-caddy wget -qO- --timeout=5 http://orchestrator:8080/health 2>&1 || echo "FAIL"

echo ""
echo "==> Caddy -> openhands:3000 /health"
docker exec loop-caddy wget -qO- --timeout=5 http://openhands:3000/health 2>&1 || echo "FAIL (502 in browser = this)"

echo ""
echo "==> loop-litellm (last 25 lines)"
docker logs loop-litellm --tail 25 2>&1 || true

echo ""
echo "==> loop-openhands (last 50 lines)"
docker logs loop-openhands --tail 50 2>&1 || true

echo ""
echo "==> loop-caddy (last 15 lines)"
docker logs loop-caddy --tail 15 2>&1 || true
