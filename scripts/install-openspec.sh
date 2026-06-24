#!/usr/bin/env bash
# Bootstrap OpenSpec in the target repo (run from a PMM clone or CI).
set -euo pipefail

TARGET_DIR="${1:?Usage: install-openspec.sh /path/to/pmm}"
NODE_MIN="20.19.0"

node -v >/dev/null 2>&1 || { echo "Node.js required (>= $NODE_MIN)"; exit 1; }

npm install -g @fission-ai/openspec@latest
cd "$TARGET_DIR"
openspec init
openspec update

echo "OpenSpec initialized in $TARGET_DIR"
echo "Next: in your AI assistant chat, run /opsx:propose <change-name>"
