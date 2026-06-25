#!/usr/bin/env bash
# Run from deploy/: bash reset-canvas.sh
exec bash "$(cd "$(dirname "$0")/.." && pwd)/scripts/reset-agent-canvas.sh"
