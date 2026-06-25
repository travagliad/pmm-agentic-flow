#!/usr/bin/env bash
# Run ON THE LINODE as root: bash scripts/stack-diagnose.sh
set -euo pipefail

DEST="${DEST:-/opt/pmm-agentic-flow/src}"
ENV_FILE="${ENV_FILE:-$DEST/.env}"
COMPOSE="docker compose --env-file $ENV_FILE -f $DEST/deploy/docker-compose.yml"

echo "==> Expected: caddy, agent-canvas, orchestrator (3 running)"
$COMPOSE ps -a

echo ""
echo "==> Public IPv4"
bash "$DEST/scripts/public-ip.sh" 2>/dev/null || curl -4 -fsSL https://ifconfig.me/ip

echo ""
echo "==> Env"
grep -E '^AGENT_CANVAS_PUBLIC_URL=' "$ENV_FILE" 2>/dev/null || true

echo ""
echo "==> Caddy -> orchestrator /orchestrator/health"
docker exec caddy wget -qO- --timeout=5 http://orchestrator:8080/orchestrator/health 2>&1 || echo "FAIL"

echo ""
echo "==> Caddy -> agent-canvas:8000"
docker exec caddy wget -qO- --timeout=5 http://agent-canvas:8000/ 2>&1 | head -c 200 || echo "FAIL"

echo ""
echo "==> agent-canvas (last 30 lines)"
docker logs agent-canvas --tail 30 2>&1 || true

echo ""
echo "==> orchestrator (last 20 lines)"
docker logs orchestrator --tail 20 2>&1 || true

echo ""
echo "==> Caddy TLS (public IPv4)"
docker exec caddy wget -qO- --timeout=5 --no-check-certificate "https://${PUBLIC_IP:-127.0.0.1}/" 2>&1 | head -c 120 || echo "HTTPS probe failed — run: bash scripts/generate-caddyfile.sh && docker compose restart caddy"
