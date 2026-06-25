#!/usr/bin/env bash
# Fix Agent Canvas volume ownership (uid 1000). Safe to re-run.
set -euo pipefail

UID_NUM="${1:-${AGENT_CANVAS_UID:-1000}}"

fix_volume() {
  local vol="$1"
  if ! docker volume inspect "$vol" >/dev/null 2>&1; then
    echo "skip (missing): $vol"
    return 0
  fi
  echo "fix $vol → uid ${UID_NUM}"
  docker run --rm -v "${vol}:/data" alpine:3.21 sh -c "
    set -e
    mkdir -p /data/storage /data/workspaces /data/automation /data/agent-canvas
    chown -R ${UID_NUM}:${UID_NUM} /data
    chmod -R u+rwX /data
  "
  docker run --rm -u "${UID_NUM}:${UID_NUM}" -v "${vol}:/oh" alpine:3.21 sh -c "
    touch /oh/automation/.write-test && rm /oh/automation/.write-test
    echo '  write test OK on $vol'
  "
}

for vol in agentic-flow_agent-canvas-state agentic-flow_agent-canvas-projects \
           deploy_agent-canvas-state deploy_agent-canvas-projects; do
  fix_volume "$vol"
done

echo "Done. If SQLite still fails, run: bash scripts/reset-agent-canvas.sh"
