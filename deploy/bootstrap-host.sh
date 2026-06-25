#!/usr/bin/env bash
# Control-plane bootstrap: clone repo, build orchestrator, enable systemd services.
set -euo pipefail

REPO="${BOOTSTRAP_REPO_URL:?BOOTSTRAP_REPO_URL required}"
DEST="${BOOTSTRAP_DEST:-/opt/pmm-agentic-flow/src}"
ENV_FILE="/etc/pmm-agentic-flow/env"

set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a

PUBLIC_IP="$(curl -4 -fsSL https://ifconfig.me/ip 2>/dev/null || curl -4 -fsSL https://ipv4.icanhazip.com)"
echo "[bootstrap-host] public IPv4: $PUBLIC_IP"
sed -i "s|__PUBLIC_IP__|$PUBLIC_IP|g" "$ENV_FILE"

echo "[bootstrap-host] clone $REPO -> $DEST"
if [ ! -d "$DEST/.git" ]; then
  git clone "$REPO" "$DEST"
else
  git -C "$DEST" pull --ff-only
fi

bash "$DEST/deploy/install-host.sh"

echo "[bootstrap-host] orchestrator"
cd "$DEST/orchestrator"
npm ci
npm run build

echo "[bootstrap-host] systemd"
install -m 0644 "$DEST/deploy/systemd/agent-canvas.service" /etc/systemd/system/agent-canvas.service
install -m 0644 "$DEST/deploy/systemd/orchestrator.service" /etc/systemd/system/orchestrator.service
systemctl daemon-reload
systemctl enable agent-canvas orchestrator
systemctl restart agent-canvas orchestrator

echo "[bootstrap-host] stack up - Canvas http://${PUBLIC_IP}:8000/ orchestrator :8080"
