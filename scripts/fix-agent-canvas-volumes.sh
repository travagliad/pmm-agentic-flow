#!/usr/bin/env bash
# Agent Canvas persists under /home/openhands/.openhands (uid 1000 by default).
set -euo pipefail

UID_NUM="${1:-${AGENT_CANVAS_UID:-1000}}"
PROJECT="${2:-deploy}"

for vol in "${PROJECT}_agent-canvas-state" "${PROJECT}_agent-canvas-projects"; do
  if docker volume inspect "$vol" >/dev/null 2>&1; then
    echo "chown ${UID_NUM}:${UID_NUM} on $vol"
    docker run --rm -v "${vol}:/data" alpine:3.21 sh -c "mkdir -p /data && chown -R ${UID_NUM}:${UID_NUM} /data && chmod -R u+rwX /data"
  else
    echo "skip (missing): $vol"
  fi
done

echo "Done. Restart: cd /opt/pmm-agentic-flow/src/deploy && docker compose --env-file ../.env up -d agent-canvas"
