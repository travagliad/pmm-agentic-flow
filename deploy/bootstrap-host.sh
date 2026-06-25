#!/usr/bin/env bash
# Control plane: orchestrator + Agent Canvas (UI at ngrok URL). Runners per ticket via Linode API.
set -euo pipefail

DEST="${BOOTSTRAP_DEST:-/opt/pmm-agentic-flow/src}"
ENV_FILE="/etc/pmm-agentic-flow/env"

set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a
export HOME="${HOME:-/root}"
export DEBIAN_FRONTEND=noninteractive

PUBLIC_IP="$(curl -4 -fsSL https://ifconfig.me/ip 2>/dev/null || curl -4 -fsSL https://ipv4.icanhazip.com)"
sed -i "s|__PUBLIC_IP__|$PUBLIC_IP|g" "$ENV_FILE"

if [ ! -d "$DEST/.git" ]; then
  echo "[bootstrap-host] ERROR: repo missing at $DEST" >&2
  exit 1
fi

bash "$DEST/deploy/install-control-plane.sh"
bash "$DEST/deploy/mount-data-volume.sh"

install -m 0755 "$DEST/deploy/agent-canvas-start.sh" /opt/pmm-agentic-flow/agent-canvas-start.sh
install -m 0644 "$DEST/deploy/systemd/agent-canvas-control-plane.service" /etc/systemd/system/agent-canvas.service

cd "$DEST/orchestrator"
npm ci
npm run build

install -m 0644 "$DEST/deploy/nginx-ingress.conf" /etc/nginx/conf.d/agentic-flow.conf
nginx -t
systemctl enable nginx
systemctl restart nginx

install -m 0644 "$DEST/deploy/systemd/orchestrator.service" /etc/systemd/system/orchestrator.service

if [ -n "${NGROK_DOMAIN:-}" ]; then
  install -m 0755 "$DEST/deploy/ngrok-tunnel.sh" /opt/pmm-agentic-flow/ngrok-tunnel.sh
  install -m 0644 "$DEST/deploy/systemd/ngrok.service" /etc/systemd/system/ngrok.service
  systemctl enable ngrok
fi

systemctl daemon-reload
systemctl enable agent-canvas orchestrator
systemctl restart agent-canvas orchestrator
[ -n "${NGROK_DOMAIN:-}" ] && systemctl restart ngrok

echo "[bootstrap-host] Agent Canvas :8000 + orchestrator :8080 (nginx :8787, ngrok public URL)"
