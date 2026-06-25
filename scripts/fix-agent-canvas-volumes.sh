#!/usr/bin/env bash
# Fix Agent Canvas volume ownership to match the openhands user in the image.
set -euo pipefail

IMAGE="${AGENT_CANVAS_IMAGE:-ghcr.io/openhands/agent-canvas:${AGENT_CANVAS_VERSION:-latest}}"

fix_volume() {
  local vol="$1"
  if ! docker volume inspect "$vol" >/dev/null 2>&1; then
    echo "skip (missing): $vol"
    return 0
  fi
  echo "fix $vol → openhands uid from $IMAGE"
  docker run --rm --user 0:0 --entrypoint /bin/sh \
    -v "${vol}:/home/openhands/.openhands" \
    "$IMAGE" \
    -ec '
      OHUID=$(id -u openhands)
      OHGID=$(id -g openhands)
      mkdir -p \
        /home/openhands/.openhands/storage \
        /home/openhands/.openhands/workspaces \
        /home/openhands/.openhands/automation \
        /home/openhands/.openhands/agent-canvas \
        /home/openhands/.openhands/agent-canvas/conversations \
        /home/openhands/.openhands/agent-canvas/bash_events
      chown -R "$OHUID:$OHGID" /home/openhands/.openhands
      chmod -R u+rwX /home/openhands/.openhands
      echo "  chown OK uid=$OHUID gid=$OHGID"
    '
  docker run --rm --user openhands --entrypoint /bin/sh \
    -v "${vol}:/home/openhands/.openhands" \
    "$IMAGE" \
    -ec '
      touch /home/openhands/.openhands/agent-canvas/conversations/.write-test
      rm -f /home/openhands/.openhands/agent-canvas/conversations/.write-test
      echo "  write test OK on '"$vol"'"
    '
}

for vol in agentic-flow_agent-canvas-state agentic-flow_agent-canvas-projects \
           deploy_agent-canvas-state deploy_agent-canvas-projects; do
  fix_volume "$vol"
done

echo "Done. Restart: docker compose --env-file .env -f deploy/docker-compose.yml up -d --force-recreate agent-canvas"
