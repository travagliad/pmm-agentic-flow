#!/usr/bin/env bash
# OpenHands 0.39 runs as enduser (OPENHANDS_SANDBOX_USER_ID, default 1000).
# Docker volumes created as root cause: Permission denied on /.openhands-state/.jwt_secret
set -euo pipefail

UID_NUM="${1:-${OPENHANDS_SANDBOX_USER_ID:-1000}}"
PROJECT="${2:-deploy}"

for vol in "${PROJECT}_openhands-state" "${PROJECT}_openhands-workspace"; do
  if docker volume inspect "$vol" >/dev/null 2>&1; then
    echo "chown ${UID_NUM}:${UID_NUM} on $vol"
    docker run --rm -v "${vol}:/data" alpine sh -c "chown -R ${UID_NUM}:${UID_NUM} /data && chmod -R u+rwX /data"
  else
    echo "skip (missing): $vol"
  fi
done

echo "Done. Restart OpenHands: cd /opt/pmm-agentic-flow/src/deploy && docker compose --env-file ../.env up -d openhands"
