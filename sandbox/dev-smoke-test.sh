#!/usr/bin/env bash
# Provision pmm-qa test DBs for dev smoke, then teardown. See docs/dev-smoke-test.md
set -euo pipefail

PMM_QA_DIR="${PMM_QA_DIR:-/projects/pmm-qa}"
FRAMEWORK="${PMM_QA_DIR}/qa-integration/pmm-framework.py"
ACTION="provision"

usage() {
  echo "Usage: $0 [--destroy] [--database <pmm-framework flags>]"
  echo "  $0 --database ps=17"
  echo "  $0 --destroy"
  exit 1
}

EXTRA_ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --destroy) ACTION="destroy"; shift ;;
    --database) shift; EXTRA_ARGS+=("--database" "$1"); shift ;;
    -h|--help) usage ;;
    *) EXTRA_ARGS+=("$1"); shift ;;
  esac
done

if [ ! -f "$FRAMEWORK" ]; then
  echo "[dev-smoke] ERROR: clone pmm-qa first (setup-pmm-workspace.sh)" >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "[dev-smoke] ERROR: docker required — install docker.io on control plane" >&2
  exit 1
fi

cd "$PMM_QA_DIR"

if [ "$ACTION" = "destroy" ]; then
  echo "[dev-smoke] tearing down pmm-framework resources"
  python3 "$FRAMEWORK" --destroy "${EXTRA_ARGS[@]}"
  exit 0
fi

if [ ${#EXTRA_ARGS[@]} -eq 0 ]; then
  echo "[dev-smoke] ERROR: pass --database flags (read database_options.py)" >&2
  usage
fi

echo "[dev-smoke] provisioning: ${EXTRA_ARGS[*]}"
python3 "$FRAMEWORK" "${EXTRA_ARGS[@]}"
echo "[dev-smoke] provisioned — run smoke tests, then: $0 --destroy ${EXTRA_ARGS[*]}"
