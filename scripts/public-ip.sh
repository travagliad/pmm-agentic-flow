#!/usr/bin/env bash
# Print this host's public IPv4 (used for AGENT_CANVAS_PUBLIC_URL).
set -euo pipefail
curl -fsSL https://ifconfig.me/ip 2>/dev/null || hostname -I | awk '{print $1}'
