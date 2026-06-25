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

bash "$DEST/deploy/install-acp-clis.sh" "$ENV_FILE"
if ! [ -x /usr/local/bin/agent ] && ! [ -x /usr/local/bin/copilot ]; then
  echo "[bootstrap-host] ERROR: no ACP CLI found at /usr/local/bin/agent or /usr/local/bin/copilot" >&2
  echo "[bootstrap-host] ERROR: Cursor CDN may block Linode IPs (HTTP 403). Set github_copilot_token in terraform.tfvars for Copilot fallback." >&2
  exit 1
fi

bash "$DEST/deploy/mount-data-volume.sh"

install -m 0755 "$DEST/deploy/agent-canvas-start.sh" /opt/pmm-agentic-flow/agent-canvas-start.sh
install -m 0755 "$DEST/deploy/wait-for-http.sh" /opt/pmm-agentic-flow/wait-for-http.sh
install -m 0644 "$DEST/deploy/systemd/agent-canvas-control-plane.service" /etc/systemd/system/agent-canvas.service

cd "$DEST/orchestrator"
npm ci
npm run build

install -m 0644 "$DEST/deploy/nginx-ingress.conf" /etc/nginx/conf.d/agentic-flow.conf
install -m 0644 "$DEST/deploy/systemd/orchestrator.service" /etc/systemd/system/orchestrator.service

if [ -n "${NGROK_DOMAIN:-}" ]; then
  install -m 0755 "$DEST/deploy/ngrok-tunnel.sh" /opt/pmm-agentic-flow/ngrok-tunnel.sh
  install -m 0644 "$DEST/deploy/systemd/ngrok.service" /etc/systemd/system/ngrok.service
fi

systemctl daemon-reload
systemctl enable nginx agent-canvas orchestrator
[ -n "${NGROK_DOMAIN:-}" ] && systemctl enable ngrok

systemctl restart agent-canvas
/opt/pmm-agentic-flow/wait-for-http.sh http://127.0.0.1:8000/ 300
bash "$DEST/deploy/seed-acp-backend.sh" "$ENV_FILE"

systemctl restart orchestrator
/opt/pmm-agentic-flow/wait-for-http.sh http://127.0.0.1:8080/orchestrator/health 60

nginx -t
systemctl restart nginx
/opt/pmm-agentic-flow/wait-for-http.sh http://127.0.0.1:8787/ 30

[ -n "${NGROK_DOMAIN:-}" ] && systemctl restart ngrok

echo "[bootstrap-host] ready: Canvas :8000 orchestrator :8080 nginx :8787"
echo ""
echo "[bootstrap-host] ACP CLI:"
if [ -x /usr/local/bin/agent ]; then
  echo "  Cursor:  /usr/local/bin/agent  ($(/usr/local/bin/agent --version 2>/dev/null || echo installed))"
  echo "  Manage Backends → command: /usr/local/bin/agent  args: acp"
elif [ -x /usr/local/bin/copilot ]; then
  echo "  Copilot: /usr/local/bin/copilot ($(/usr/local/bin/copilot --version 2>/dev/null | head -1 || echo installed))"
  echo "  (Cursor agent unavailable — CDN may block Linode IPs)"
  echo "  Auto-seeded via seed-acp-backend.sh → command: /usr/local/bin/copilot  args: acp"
else
  echo "  NONE — set github_copilot_token in terraform.tfvars and re-run bootstrap"
  echo "  Manual Manage Backends → command: /usr/local/bin/copilot  args: acp"
fi
