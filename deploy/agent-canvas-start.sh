#!/usr/bin/env bash
set -euo pipefail
set -a
# shellcheck source=/dev/null
source /etc/pmm-agentic-flow/env
set +a
exec "$(command -v agent-canvas)" --public --port 8000
