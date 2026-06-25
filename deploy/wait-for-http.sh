#!/usr/bin/env bash
# Wait until URL returns HTTP 2xx/3xx/401/403 (service is listening).
set -euo pipefail
URL="${1:?url}"
SECONDS_MAX="${2:-300}"
for ((i = 1; i <= SECONDS_MAX; i++)); do
  code=$(curl -s -o /dev/null -w "%{http_code}" "$URL" 2>/dev/null || echo "000")
  if [[ "$code" =~ ^(200|301|302|401|403)$ ]]; then
    echo "[wait-for-http] $URL -> $code"
    exit 0
  fi
  sleep 1
done
echo "[wait-for-http] timeout: $URL (last code $code)" >&2
exit 1
