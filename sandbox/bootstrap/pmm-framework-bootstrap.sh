#!/usr/bin/env bash
# Bootstrap PMM test environment inside an OpenHands sandbox using pmm-qa conventions.
# See: percona/pmm-qa qa-integration/ + AGENTS.md
set -euo pipefail

PMM_QA_DIR="${PMM_QA_DIR:-/workspace/pmm-qa}"
PMM_SERVER_URL="${PMM_SERVER_URL:-}"
FRAMEWORK="${PMM_QA_DIR}/qa-integration/pmm-framework.py"

if [ ! -d "$PMM_QA_DIR" ]; then
  echo "pmm-qa not cloned at $PMM_QA_DIR"
  exit 1
fi

cd "$PMM_QA_DIR"

echo "==> Reading qa-integration docs"
test -f qa-integration/pmm_qa/README.md

if [ -n "$PMM_SERVER_URL" ]; then
  echo "==> External PMM server mode: $PMM_SERVER_URL"
  export PMM_SERVER_URL
  exit 0
fi

if [ ! -f "$FRAMEWORK" ]; then
  echo "pmm-framework.py not found at $FRAMEWORK"
  exit 1
fi

echo "==> Provisioning via pmm-framework.py (Docker network: pmm-qa)"
# Exact flags are ticket-specific — agent must read database_options.py
# Example: python3 qa-integration/pmm-framework.py --database ps=8.0
python3 "$FRAMEWORK" --help

echo "Done. Set PMM_SERVER_URL to the provisioned server before running tests."
