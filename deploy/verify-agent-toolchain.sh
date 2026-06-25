#!/usr/bin/env bash
# Verify agentcanvas can run PMM dev toolchain (fail bootstrap if not).
set -euo pipefail

AGENT_USER="${AGENT_USER:-agentcanvas}"

if ! id "$AGENT_USER" >/dev/null 2>&1; then
  echo "[verify-agent-toolchain] SKIP — user $AGENT_USER missing" >&2
  exit 0
fi

echo "[verify-agent-toolchain] checking as $AGENT_USER..."
runuser -u "$AGENT_USER" -- env PATH="/usr/local/bin:/usr/bin:/bin" bash -lc '
  set -e
  for cmd in curl make go node yarn gh; do
    command -v "$cmd" >/dev/null || { echo "MISSING: $cmd" >&2; exit 1; }
  done
  echo "  go: $(go version)"
  echo "  node: $(node --version)"
  echo "  yarn: $(yarn --version)"
  echo "  gh: $(gh --version | head -1)"
  if [ -d /projects/pmm/ui/node_modules ]; then
    echo "  ui/node_modules: present"
  else
    echo "  WARN: /projects/pmm/ui/node_modules missing — run yarn install in ui/"
  fi
'
