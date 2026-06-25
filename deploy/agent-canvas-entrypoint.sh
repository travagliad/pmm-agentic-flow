#!/usr/bin/env bash
# Runs before the official agent-canvas entrypoint — volume permissions + agent CLIs.
set -euo pipefail

OH=/home/openhands/.openhands
LOCAL=/home/openhands/.local
ENTRYPOINT="/opt/agent-canvas/entrypoint.sh"
AGENT_BIN=/usr/local/bin/agent
COPILOT_BIN=/usr/local/bin/copilot
CURSOR_OPT_DIR=/opt/cursor-agent
CURL_IPV4_DIR=/tmp/curl-ipv4

canvas_ids() {
  if id openhands >/dev/null 2>&1; then
    echo "$(id -u openhands) $(id -g openhands)"
  else
    echo "${AGENT_CANVAS_UID:-1000} ${AGENT_CANVAS_GID:-${AGENT_CANVAS_UID:-1000}}"
  fi
}

run_as_openhands() {
  local cmd="$1"
  if id openhands >/dev/null 2>&1; then
    su -s /bin/bash openhands -c "export HOME=/home/openhands PATH=$CURL_IPV4_DIR:/usr/local/bin:/home/openhands/.local/bin:\$PATH; ${cmd}"
  else
    HOME=/home/openhands PATH="$CURL_IPV4_DIR:/usr/local/bin:/home/openhands/.local/bin:$PATH" bash -c "${cmd}"
  fi
}

ensure_curl_ipv4_wrapper() {
  mkdir -p "$CURL_IPV4_DIR"
  cat >"$CURL_IPV4_DIR/curl" <<'EOF'
#!/bin/sh
exec /usr/bin/curl -4 "$@"
EOF
  chmod +x "$CURL_IPV4_DIR/curl"
}

cursor_lab_version() {
  local script
  script="$(PATH="$CURL_IPV4_DIR:$PATH" curl -fsSL https://cursor.com/install)"
  echo "$script" | grep -oE 'lab/[0-9]{4}\.[0-9]{2}\.[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9a-f]+' | head -1 | cut -d/ -f2
}

install_cursor_cli() {
  if [ -x "$AGENT_BIN" ]; then
    echo "[entrypoint-wrapper] cursor CLI: $AGENT_BIN"
    return 0
  fi
  echo "[entrypoint-wrapper] installing cursor CLI to $AGENT_BIN (outside .local volume)..."
  local version url dest attempt
  version="$(cursor_lab_version)"
  if [ -z "$version" ]; then
    echo "[entrypoint-wrapper] ERROR: could not parse Cursor CLI version from install script" >&2
    exit 1
  fi
  url="https://downloads.cursor.com/lab/${version}/linux/x64/agent-cli-package.tar.gz"
  dest="${CURSOR_OPT_DIR}/${version}"
  for attempt in 1 2 3; do
    rm -rf "$dest"
    mkdir -p "$dest"
    if PATH="$CURL_IPV4_DIR:$PATH" curl -fSL "$url" | tar --strip-components=1 -xzf - -C "$dest"; then
      install -m 0755 "$dest/cursor-agent" "$AGENT_BIN"
      ln -sf "$AGENT_BIN" /usr/local/bin/cursor-agent
      echo "[entrypoint-wrapper] cursor CLI installed: $($AGENT_BIN --version 2>/dev/null || echo "$version")"
      return 0
    fi
    echo "[entrypoint-wrapper] cursor CLI download attempt ${attempt}/3 failed" >&2
    sleep 5
  done
  echo "[entrypoint-wrapper] ERROR: cursor CLI missing at $AGENT_BIN" >&2
  exit 1
}

install_copilot_cli() {
  if [ -x "$COPILOT_BIN" ]; then
    echo "[entrypoint-wrapper] copilot CLI: $COPILOT_BIN"
    return 0
  fi
  echo "[entrypoint-wrapper] installing copilot CLI..."
  local attempt
  for attempt in 1 2 3; do
    if run_as_openhands 'PATH=/usr/local/bin:$PATH curl -fsSL https://gh.io/copilot-install | bash'; then
      if [ -x "$LOCAL/bin/copilot" ] && [ ! -e "$COPILOT_BIN" ]; then
        ln -sf "$LOCAL/bin/copilot" "$COPILOT_BIN"
      fi
      if [ -x "$COPILOT_BIN" ]; then
        echo "[entrypoint-wrapper] copilot CLI installed: $($COPILOT_BIN --version 2>/dev/null || echo ok)"
        return 0
      fi
    fi
    echo "[entrypoint-wrapper] copilot CLI install attempt ${attempt}/3 failed" >&2
  done
  echo "[entrypoint-wrapper] WARNING: copilot CLI install failed (optional)" >&2
}

read -r UID_NUM GID_NUM <<< "$(canvas_ids)"
echo "[entrypoint-wrapper] volume owner uid:gid = ${UID_NUM}:${GID_NUM}"

ensure_curl_ipv4_wrapper

mkdir -p \
  "$OH/storage" \
  "$OH/workspaces" \
  "$OH/automation" \
  "$OH/agent-canvas" \
  "$OH/agent-canvas/conversations" \
  "$OH/agent-canvas/bash_events" \
  "$LOCAL/bin" \
  "$CURSOR_OPT_DIR"

chown -R "${UID_NUM}:${GID_NUM}" "$OH" "$LOCAL"
chmod -R u+rwX "$OH" "$LOCAL"
touch "$OH/automation/.write-test" && rm -f "$OH/automation/.write-test"

install_cursor_cli
install_copilot_cli

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
