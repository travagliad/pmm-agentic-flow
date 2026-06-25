#!/usr/bin/env bash
# Env vars come from systemd EnvironmentFile (root reads, then drops to agentcanvas).
set -euo pipefail
exec /usr/bin/agent-canvas --public --port 8000
