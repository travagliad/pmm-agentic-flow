#!/usr/bin/env bash
# Runs before the official agent-canvas entrypoint — fixes volume permissions.
set -euo pipefail

OH=/home/openhands/.openhands
ENTRYPOINT="/opt/agent-canvas/entrypoint.sh"

canvas_ids() {
  if id openhands >/dev/null 2>&1; then
    echo "$(id -u openhands) $(id -g openhands)"
  else
    echo "${AGENT_CANVAS_UID:-1000} ${AGENT_CANVAS_GID:-${AGENT_CANVAS_UID:-1000}}"
  fi
}

read -r UID_NUM GID_NUM <<< "$(canvas_ids)"
echo "[entrypoint-wrapper] volume owner uid:gid = ${UID_NUM}:${GID_NUM}"

mkdir -p \
  "$OH/storage" \
  "$OH/workspaces" \
  "$OH/automation" \
  "$OH/agent-canvas" \
  "$OH/agent-canvas/conversations" \
  "$OH/agent-canvas/bash_events"

chown -R "${UID_NUM}:${GID_NUM}" "$OH"
chmod -R u+rwX "$OH"
touch "$OH/automation/.write-test" && rm -f "$OH/automation/.write-test"

if [ ! -x "$ENTRYPOINT" ]; then
  echo "ERROR: $ENTRYPOINT not found" >&2
  exit 1
fi

run_as_canvas_user() {
  if id openhands >/dev/null 2>&1; then
    exec su -s /bin/bash openhands -c 'exec "$0" "$@"' -- "$ENTRYPOINT" "$@"
  fi
  if command -v gosu >/dev/null 2>&1; then
    exec gosu "${UID_NUM}:${GID_NUM}" "$ENTRYPOINT" "$@"
  fi
  if command -v setpriv >/dev/null 2>&1; then
    exec setpriv --reuid="$UID_NUM" --regid="$GID_NUM" --init-groups -- "$ENTRYPOINT" "$@"
  fi
  echo "ERROR: cannot drop privileges to uid ${UID_NUM}" >&2
  exit 1
}

if [ "$(id -u)" -eq 0 ]; then
  run_as_canvas_user "$@"
fi

exec "$ENTRYPOINT" "$@"
