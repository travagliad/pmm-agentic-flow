#!/usr/bin/env bash
# Fix Agent Canvas volume ownership (uid 1000). Safe to re-run.
set -euo pipefail

UID_NUM="${1:-${AGENT_CANVAS_UID:-1000}}"

fix_volume() {
  local vol="$1"
  local subdirs="${2:-}"
  if ! docker volume inspect "$vol" >/dev/null 2>&1; then
    echo "skip (missing): $vol"
    return 0
  fi
  echo "fix $vol → uid ${UID_NUM}"
  docker run --rm -v "${vol}:/data" alpine:3.21 sh -c "
    set -e
    mkdir -p /data ${subdirs}
    chown -R ${UID_NUM}:${UID_NUM} /data
    chmod -R u+rwX /data
  "
}

# Compose project name is 'agentic-flow' (name: in docker-compose.yml)
for vol in agentic-flow_agent-canvas-state agentic-flow_agent-canvas-projects; do
  case "$vol" in
    *state*) fix_volume "$vol" "/data/storage /data/workspaces /data/automation" ;;
    *) fix_volume "$vol" "/data" ;;
  esac
done

# Legacy project names from older deploys
for vol in deploy_agent-canvas-state deploy_agent-canvas-projects; do
  case "$vol" in
    *state*) fix_volume "$vol" "/data/storage /data/workspaces /data/automation" ;;
    *) fix_volume "$vol" "/data" ;;
  esac
done

echo "Done. Restart: cd deploy && docker compose --env-file ../.env up -d --force-recreate agent-canvas"
