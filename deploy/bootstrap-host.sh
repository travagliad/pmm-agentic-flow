#!/usr/bin/env bash
# Control plane: orchestrator only. Chats run on per-ticket Linode runners.
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

bash "$DEST/deploy/mount-data-volume.sh"
bash "$DEST/deploy/install-control-plane.sh"

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
systemctl enable orchestrator
systemctl restart orchestrator
[ -n "${NGROK_DOMAIN:-}" ] && systemctl restart ngrok

echo "[bootstrap-host] orchestrator :8080 (runners provisioned per chat via Linode API)"
