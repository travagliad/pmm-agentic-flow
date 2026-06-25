#!/usr/bin/env bash
# Pre-PR checks for percona/pmm — run from repo root (/projects/pmm).
set -euo pipefail

PMM_DIR="${1:-/projects/pmm}"
BASE_REF="${BASE_REF:-origin/main}"

cd "$PMM_DIR"
git fetch origin main 2>/dev/null || true

CHANGED=$(git diff --name-only "${BASE_REF}"...HEAD 2>/dev/null || git diff --name-only HEAD~1)

if [ -z "$CHANGED" ]; then
  echo "[verify-pmm] no changes vs ${BASE_REF}"
  exit 0
fi

echo "[verify-pmm] changed files vs ${BASE_REF}:"
echo "$CHANGED" | sed 's/^/  /'

# Guard: mass api/* regeneration without matching .proto edits
api_gen=$(echo "$CHANGED" | grep -cE '^api/.*\.(pb\.go|pb\.validate\.go|swagger\.json)$' || true)
proto=$(echo "$CHANGED" | grep -cE '\.proto$' || true)
if [ "$api_gen" -gt 15 ] && [ "$proto" -lt 2 ]; then
  echo "[verify-pmm] ERROR: ${api_gen} generated api/ files changed but only ${proto} .proto file(s)."
  echo "  Do NOT run 'make gen' at repo root. Regenerate only the API package you edited:"
  echo "  make -C api gen   # only after editing the relevant .proto under api/"
  exit 1
fi

# UI lint (same as CI: ui/Makefile lint -> yarn lint)
if echo "$CHANGED" | grep -qE '^ui/'; then
  echo "[verify-pmm] UI files touched — running make -C ui lint"
  make -C ui lint
fi

# Go tests for touched packages (fast gate before PR)
go_dirs=$(echo "$CHANGED" | grep -E '\.go$' | xargs -r dirname | sort -u | grep -E '^(agent|managed|api)/' || true)
for dir in $go_dirs; do
  if [ -f "$dir/go.mod" ] || [ -f "go.mod" ]; then
    echo "[verify-pmm] go test ./${dir}/..."
    go test "./${dir}/..." || exit 1
  fi
done

echo "[verify-pmm] OK"
