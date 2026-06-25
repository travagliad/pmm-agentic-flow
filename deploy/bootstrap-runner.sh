#!/usr/bin/env bash
# One runner Linode per ticket/chat: Agent Canvas + repo workspace on the VM (no Docker).
set -euo pipefail

DEST="${BOOTSTRAP_DEST:-/opt/pmm-agentic-flow/src}"
ENV_FILE="/etc/pmm-agentic-flow/runner.env"

set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a

PUBLIC_IP="$(curl -4 -fsSL https://ifconfig.me/ip 2>/dev/null || curl -4 -fsSL https://ipv4.icanhazip.com)"
sed -i "s|__RUNNER_IP__|$PUBLIC_IP|g" "$ENV_FILE"
export AGENT_CANVAS_PUBLIC_URL="http://${PUBLIC_IP}:8000"

bash "$DEST/deploy/install-runner.sh"

if [ -n "${GITHUB_TOKEN:-}" ]; then
  export PMM_DIR=/projects/pmm PMM_QA_DIR=/projects/pmm-qa TICKET_KEY="${TICKET_KEY:-}"
  bash "$DEST/sandbox/setup-pmm-workspace.sh" || echo "[bootstrap-runner] workspace setup warning (non-fatal)"
fi

install -m 0644 "$DEST/deploy/systemd/agent-canvas.service" /etc/systemd/system/agent-canvas.service
systemctl daemon-reload
systemctl enable agent-canvas
systemctl restart agent-canvas
sleep 5
bash "$DEST/deploy/seed-acp-backend.sh" "$ENV_FILE"

echo "[bootstrap-runner] ready http://${PUBLIC_IP}:8000/ ticket=${TICKET_KEY:-unknown}"
if [ -x /usr/local/bin/copilot ] && ! [ -x /usr/local/bin/agent ]; then
  echo "[bootstrap-runner] ACP: Copilot auto-seeded (/usr/local/bin/copilot acp)"
fi
