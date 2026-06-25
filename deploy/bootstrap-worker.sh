#!/usr/bin/env bash
# QA worker bootstrap: host Agent Canvas + shared PMM container. Chats = Docker sandboxes on this VM.
set -euo pipefail

DEST="${BOOTSTRAP_DEST:-/opt/pmm-agentic-flow/src}"
ENV_FILE="/etc/pmm-agentic-flow/worker.env"
PMM_IMAGE="${PMM_SERVER_IMAGE:?PMM_SERVER_IMAGE required}"

set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a

PUBLIC_IP="$(curl -4 -fsSL https://ifconfig.me/ip 2>/dev/null || curl -4 -fsSL https://ipv4.icanhazip.com)"
sed -i "s|__WORKER_IP__|$PUBLIC_IP|g" "$ENV_FILE"
export AGENT_CANVAS_PUBLIC_URL="http://${PUBLIC_IP}:8000"

bash "$DEST/deploy/install-host.sh"

install -m 0644 "$DEST/deploy/systemd/agent-canvas.service" /etc/systemd/system/agent-canvas.service
systemctl daemon-reload
systemctl enable agent-canvas
systemctl restart agent-canvas

echo "[bootstrap-worker] PMM server $PMM_IMAGE"
docker pull "$PMM_IMAGE"
docker rm -f pmm-server 2>/dev/null || true
docker run -d --name pmm-server --restart unless-stopped -p 8443:8443 -p 8081:8080 "$PMM_IMAGE"

echo "[bootstrap-worker] ready - Canvas http://${PUBLIC_IP}:8000/ PMM https://${PUBLIC_IP}:8443/"
