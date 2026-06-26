#!/usr/bin/env bash
# Rebuild orchestrator + reload nginx after git pull. Run from anywhere.
set -euo pipefail

DEST="${PMM_AGENTIC_FLOW_SRC:-/opt/pmm-agentic-flow/src}"

if [ ! -d "$DEST/.git" ]; then
  echo "[reload-orchestrator] ERROR: repo not found at $DEST" >&2
  exit 1
fi

echo "[reload-orchestrator] building orchestrator in $DEST/orchestrator"
cd "$DEST/orchestrator"
npm ci
npm run build

echo "[reload-orchestrator] nginx config"
install -m 0644 "$DEST/deploy/nginx-ingress.conf" /etc/nginx/conf.d/agentic-flow.conf
nginx -t
systemctl reload nginx

echo "[reload-orchestrator] restart orchestrator"
systemctl restart orchestrator

echo "[reload-orchestrator] done"
