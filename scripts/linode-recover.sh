#!/usr/bin/env bash
# Run ON THE LINODE as root after SSH.
set -euo pipefail

DEST=/opt/pmm-agentic-flow/src
ENV_FILE=/etc/pmm-agentic-flow/env

if [ ! -d "$DEST/.git" ]; then
  echo "==> Repo missing — cloning..."
  mkdir -p /opt/pmm-agentic-flow
  git clone https://github.com/travagliad/pmm-agentic-flow.git "$DEST"
fi

PUBLIC_IP="$(bash "$DEST/scripts/public-ip.sh" 2>/dev/null || curl -4 -fsSL https://ifconfig.me/ip)"

echo "==> IPv4: $PUBLIC_IP"
echo "==> URL: https://$PUBLIC_IP/"

if [ -f "$ENV_FILE" ]; then
  sed -i "s|__PUBLIC_IP__|$PUBLIC_IP|g" "$ENV_FILE"
  sed -i "s|^AGENT_CANVAS_PUBLIC_URL=.*|AGENT_CANVAS_PUBLIC_URL=https://$PUBLIC_IP|" "$ENV_FILE"
  grep -q '^AGENT_CANVAS_API_KEY=' "$ENV_FILE" || echo "AGENT_CANVAS_API_KEY=$(openssl rand -hex 24)" >> "$ENV_FILE"
  grep -q '^AGENT_CANVAS_SECRET_KEY=' "$ENV_FILE" || echo "AGENT_CANVAS_SECRET_KEY=$(openssl rand -hex 24)" >> "$ENV_FILE"
  grep -q '^AGENT_CANVAS_VERSION=' "$ENV_FILE" || echo 'AGENT_CANVAS_VERSION=latest' >> "$ENV_FILE"
  cp "$ENV_FILE" "$DEST/.env"
else
  echo "ERROR: $ENV_FILE missing — cloud-init may have failed."
  exit 1
fi

bash "$DEST/scripts/stack-cleanup.sh" || true
bash "$DEST/scripts/fix-agent-canvas-volumes.sh" "${AGENT_CANVAS_UID:-1000}" deploy

echo "==> Starting stack (3 containers: caddy, agent-canvas, orchestrator)..."
cd "$DEST/deploy"
docker compose --env-file "$DEST/.env" pull
docker compose --env-file "$DEST/.env" up -d --build

echo ""
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'
echo ""
echo "Open: https://$PUBLIC_IP/"
echo "API key: grep AGENT_CANVAS_API_KEY $DEST/.env"
echo "Jira webhook: https://$PUBLIC_IP/hooks/jira"
