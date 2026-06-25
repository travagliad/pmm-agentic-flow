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

AGENT_BIN="/home/openhands/.local/bin/agent"

install_cursor_cli() {
  if [ -x "$AGENT_BIN" ]; then
    echo "[entrypoint-wrapper] cursor CLI: $AGENT_BIN"
    return 0
  fi
  if [ -z "${CURSOR_API_KEY:-}" ] && [ "${INSTALL_CURSOR_CLI:-1}" != "1" ]; then
    echo "[entrypoint-wrapper] cursor CLI not installed (set CURSOR_API_KEY or INSTALL_CURSOR_CLI=1)"
    return 0
  fi
  echo "[entrypoint-wrapper] installing cursor CLI (one-time per volume)..."
  if id openhands >/dev/null 2>&1; then
    su -s /bin/bash openhands -c 'curl -fsSL https://cursor.com/install | bash' || true
  else
    curl -fsSL https://cursor.com/install | bash || true
  fi
  if [ -d /home/openhands/.local ]; then
    chown -R "${UID_NUM}:${GID_NUM}" /home/openhands/.local
  fi
  if [ -x "$AGENT_BIN" ]; then
    echo "[entrypoint-wrapper] cursor CLI installed: $($AGENT_BIN --version 2>/dev/null || echo ok)"
  else
    echo "[entrypoint-wrapper] WARNING: cursor CLI install failed — ACP command 'agent' will not work" >&2
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

install_cursor_cli

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
