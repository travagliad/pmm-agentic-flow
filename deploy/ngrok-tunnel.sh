#!/usr/bin/env bash
set -euo pipefail
set -a
# shellcheck source=/dev/null
source /etc/pmm-agentic-flow/env
set +a
export HOME="${HOME:-/root}"
exec "$(command -v ngrok)" http 8787 --url="${NGROK_DOMAIN}"
