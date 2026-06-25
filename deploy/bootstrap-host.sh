#!/usr/bin/env bash
# Control-plane bootstrap: clone repo, build orchestrator, enable systemd services.
set -euo pipefail

DEST="${BOOTSTRAP_DEST:-/opt/pmm-agentic-flow/src}"
ENV_FILE="/etc/pmm-agentic-flow/env"

set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a

PUBLIC_IP="$(curl -4 -fsSL https://ifconfig.me/ip 2>/dev/null || curl -4 -fsSL https://ipv4.icanhazip.com)"
echo "[bootstrap-host] public IPv4: $PUBLIC_IP"
sed -i "s|__PUBLIC_IP__|$PUBLIC_IP|g" "$ENV_FILE"

if [ ! -d "$DEST/.git" ]; then
  echo "[bootstrap-host] ERROR: repo missing at $DEST" >&2
  exit 1
fi

bash "$DEST/deploy/mount-data-volume.sh"
bash "$DEST/deploy/install-host.sh"

echo "[bootstrap-host] orchestrator"
cd "$DEST/orchestrator"
npm ci
npm run build

install -m 0644 "$DEST/deploy/nginx-ingress.conf" /etc/nginx/conf.d/agentic-flow.conf
nginx -t
systemctl enable nginx
systemctl restart nginx

install -m 0644 "$DEST/deploy/systemd/agent-canvas.service" /etc/systemd/system/agent-canvas.service
install -m 0644 "$DEST/deploy/systemd/orchestrator.service" /etc/systemd/system/orchestrator.service

if [ -n "${NGROK_DOMAIN:-}" ]; then
  sed -i "s|AGENT_CANVAS_PUBLIC_URL=.*|AGENT_CANVAS_PUBLIC_URL=${NGROK_DOMAIN}|" "$ENV_FILE"
  install -m 0644 "$DEST/deploy/systemd/ngrok.service" /etc/systemd/system/ngrok.service
  systemctl enable ngrok
fi

systemctl daemon-reload
systemctl enable agent-canvas orchestrator
systemctl restart agent-canvas orchestrator
[ -n "${NGROK_DOMAIN:-}" ] && systemctl restart ngrok

if [ -n "${NGROK_DOMAIN:-}" ]; then
  echo "[bootstrap-host] public URL: ${NGROK_DOMAIN}"
else
  echo "[bootstrap-host] direct ports (dev only): http://${PUBLIC_IP}:8000/"
fi
