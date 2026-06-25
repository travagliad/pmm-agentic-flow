#!/usr/bin/env bash
# Runs before the official agent-canvas entrypoint — fixes volume permissions.
set -euo pipefail

OH=/home/openhands/.openhands
UID_NUM="${AGENT_CANVAS_UID:-1000}"

mkdir -p \
  "$OH/storage" \
  "$OH/workspaces" \
  "$OH/automation" \
  "$OH/agent-canvas" \
  "$OH/agent-canvas/conversations" \
  "$OH/agent-canvas/bash_events"

chown -R "${UID_NUM}:${UID_NUM}" "$OH"
chmod -R u+rwX "$OH"
touch "$OH/automation/.write-test" && rm -f "$OH/automation/.write-test"

ENTRYPOINT="/opt/agent-canvas/entrypoint.sh"
if [ ! -x "$ENTRYPOINT" ]; then
  echo "ERROR: $ENTRYPOINT not found" >&2
  exit 1
fi

if [ "$(id -u)" -eq 0 ] && [ "$(id -u)" != "$UID_NUM" ]; then
  if command -v runuser >/dev/null 2>&1; then
    exec runuser -u "#${UID_NUM}" -- "$ENTRYPOINT" "$@"
  elif command -v gosu >/dev/null 2>&1; then
    exec gosu "${UID_NUM}" "$ENTRYPOINT" "$@"
  fi
fi

exec "$ENTRYPOINT" "$@"
