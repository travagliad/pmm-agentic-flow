#!/usr/bin/env bash
# Install Cursor agent CLI to /usr/local/bin/agent (host VM, not ~/.local volume).
set -euo pipefail

AGENT_BIN=/usr/local/bin/agent
CURL_IPV4_DIR=/tmp/curl-ipv4

if [ -x "$AGENT_BIN" ]; then
  echo "[cursor-cli] already installed: $AGENT_BIN"
  exit 0
fi

mkdir -p "$CURL_IPV4_DIR"
cat >"$CURL_IPV4_DIR/curl" <<'EOF'
#!/bin/sh
exec /usr/bin/curl -4 "$@"
EOF
chmod +x "$CURL_IPV4_DIR/curl"

script="$(PATH="$CURL_IPV4_DIR:$PATH" curl -fsSL https://cursor.com/install)"
version="$(echo "$script" | grep -oE 'lab/[0-9]{4}\.[0-9]{2}\.[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9a-f]+' | head -1 | cut -d/ -f2)"
if [ -z "$version" ]; then
  echo "[cursor-cli] ERROR: could not parse Cursor CLI version" >&2
  exit 1
fi

url="https://downloads.cursor.com/lab/${version}/linux/x64/agent-cli-package.tar.gz"
dest="/opt/cursor-agent/${version}"
rm -rf "$dest"
mkdir -p "$dest"
PATH="$CURL_IPV4_DIR:$PATH" curl -fSL "$url" | tar --strip-components=1 -xzf - -C "$dest"
install -m 0755 "$dest/cursor-agent" "$AGENT_BIN"
ln -sf "$AGENT_BIN" /usr/local/bin/cursor-agent
echo "[cursor-cli] installed: $($AGENT_BIN --version 2>/dev/null || echo "$version")"
