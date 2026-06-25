#!/usr/bin/env bash
# Install Cursor agent CLI to /usr/local/bin/agent (host VM, not ~/.local volume).
set -euo pipefail

AGENT_BIN=/usr/local/bin/agent
CURL_IPV4_DIR=/tmp/curl-ipv4
MAX_ATTEMPTS=3

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

curl_with_retries() {
  local url="$1"
  local output="$2"
  local attempt err_file http_code

  for attempt in $(seq 1 "$MAX_ATTEMPTS"); do
    err_file="$(mktemp)"
    if http_code="$(PATH="$CURL_IPV4_DIR:$PATH" curl -fSL -w '%{http_code}' -o "$output" "$url" 2>"$err_file")"; then
      rm -f "$err_file"
      return 0
    fi
    if [ "$http_code" = "403" ]; then
      echo "[cursor-cli] ERROR: HTTP 403 for $url" >&2
      echo "[cursor-cli] ERROR: Lab version may be unpublished, or download URL was parsed incorrectly." >&2
    elif [ -n "$http_code" ] && [ "$http_code" != "000" ]; then
      echo "[cursor-cli] ERROR: HTTP $http_code downloading $url (attempt $attempt/$MAX_ATTEMPTS)" >&2
    else
      echo "[cursor-cli] ERROR: download failed for $url (attempt $attempt/$MAX_ATTEMPTS)" >&2
    fi
    if [ -s "$err_file" ]; then
      sed 's/^/[cursor-cli] curl: /' "$err_file" >&2
    fi
    rm -f "$err_file"
    [ "$attempt" -lt "$MAX_ATTEMPTS" ] && sleep 2
  done
  return 1
}

resolve_download_url() {
  local script="$1"
  local url_template version url

  url_template="$(printf '%s\n' "$script" | grep -m1 '^DOWNLOAD_URL=' | sed 's/^DOWNLOAD_URL="//;s/"$//' || true)"
  if [ -n "$url_template" ]; then
    url="${url_template//\$\{OS\}/linux}"
    url="${url//\$\{ARCH\}/x64}"
    printf '%s\n' "$url"
    return 0
  fi

  version="$(printf '%s\n' "$script" | grep -oE '[0-9]{4}\.[0-9]{2}\.[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9a-f]+-[0-9a-f]+' | head -1)"
  if [ -n "$version" ]; then
    printf '%s\n' "https://downloads.cursor.com/lab/${version}/linux/x64/agent-cli-package.tar.gz"
    return 0
  fi

  return 1
}

script="$(PATH="$CURL_IPV4_DIR:$PATH" curl -fsSL https://cursor.com/install)"
url="$(resolve_download_url "$script" || true)"
if [ -z "$url" ]; then
  echo "[cursor-cli] ERROR: could not resolve Cursor CLI download URL from install script" >&2
  exit 1
fi

version_dir="$(printf '%s\n' "$script" | grep -oE '[0-9]{4}\.[0-9]{2}\.[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9a-f]+-[0-9a-f]+' | head -1)"
echo "[cursor-cli] download: $url"

tarball="$(mktemp /tmp/cursor-agent-cli.XXXXXX.tar.gz)"
if ! curl_with_retries "$url" "$tarball"; then
  rm -f "$tarball"
  exit 1
fi

if ! gzip -t "$tarball" 2>/dev/null; then
  echo "[cursor-cli] ERROR: downloaded file is not a valid gzip tarball" >&2
  head -c 200 "$tarball" | tr -d '\0' | sed 's/^/[cursor-cli] response preview: /' >&2 || true
  rm -f "$tarball"
  exit 1
fi

dest="/opt/cursor-agent/${version_dir:-unknown}"
rm -rf "$dest"
mkdir -p "$dest"
if ! tar --strip-components=1 -xzf "$tarball" -C "$dest"; then
  echo "[cursor-cli] ERROR: failed to extract $tarball" >&2
  rm -f "$tarball"
  exit 1
fi
rm -f "$tarball"

if [ ! -f "$dest/cursor-agent" ]; then
  echo "[cursor-cli] ERROR: cursor-agent binary missing after extract" >&2
  exit 1
fi

install -m 0755 "$dest/cursor-agent" "$AGENT_BIN"
ln -sf "$AGENT_BIN" /usr/local/bin/cursor-agent
echo "[cursor-cli] installed: $($AGENT_BIN --version 2>/dev/null || echo "$version_dir")"
