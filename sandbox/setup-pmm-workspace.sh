#!/usr/bin/env bash
# PMM multi-repo workspace bootstrap for agent sandboxes.
set -euo pipefail

PMM_DIR="${PMM_DIR:-/projects/pmm}"
PMM_QA_DIR="${PMM_QA_DIR:-/projects/pmm-qa}"
AGENT_STATE_DIR="${AGENT_STATE_DIR:-/projects/.agent}"
PMM_REPO="${PMM_REPO:-https://github.com/percona/pmm.git}"
PMM_QA_REPO="${PMM_QA_REPO:-https://github.com/percona/pmm-qa.git}"
PMM_BRANCH="${PMM_BRANCH:-main}"
TICKET_KEY="${TICKET_KEY:-}"
CHANGE_ID="${CHANGE_ID:-}"

mkdir -p "$AGENT_STATE_DIR"

clone_repo() {
  local url="$1" dir="$2" branch="$3"
  if [ -d "$dir/.git" ]; then
    git -C "$dir" fetch origin
    git -C "$dir" checkout "$branch" 2>/dev/null || git -C "$dir" checkout -B "$branch"
    git -C "$dir" pull --ff-only origin "$branch" 2>/dev/null || true
  else
    git clone --depth 1 --branch "$branch" "$url" "$dir"
  fi
}

echo "==> Cloning PMM dev repo"
clone_repo "$PMM_REPO" "$PMM_DIR" "$PMM_BRANCH"

echo "==> Cloning PMM QA repo"
clone_repo "$PMM_QA_REPO" "$PMM_QA_DIR" "main"

if [ -n "$TICKET_KEY" ] && [ -n "$CHANGE_ID" ]; then
  FEATURE_BRANCH="agent/${TICKET_KEY}-${CHANGE_ID#${TICKET_KEY}-}"
  git -C "$PMM_DIR" checkout -B "$FEATURE_BRANCH"
fi

echo "==> OpenSpec bootstrap (if missing)"
if [ ! -d "$PMM_DIR/openspec" ]; then
  if command -v openspec >/dev/null 2>&1; then
    (cd "$PMM_DIR" && openspec init && openspec update) || true
  else
    npm install -g @fission-ai/openspec@latest 2>/dev/null || true
    (cd "$PMM_DIR" && openspec init && openspec update) || true
  fi
fi

echo "==> Initial agent state"
STATE_FILE="$AGENT_STATE_DIR/state.json"
if [ ! -f "$STATE_FILE" ]; then
  cat >"$STATE_FILE" <<EOF
{
  "ticket": "${TICKET_KEY}",
  "changeId": "${CHANGE_ID}",
  "phase": "IN_PROGRESS",
  "buildIteration": 0,
  "pmmServerUrl": "",
  "repos": {
    "pmm": "$PMM_DIR",
    "pmmQa": "$PMM_QA_DIR"
  }
}
EOF
fi

echo "==> PMM test environment (In QA only)"
echo "    Do NOT run on In Progress — orchestrator starts FB + runner on In QA."
echo "    When in QA: python3 $PMM_QA_DIR/qa-integration/pmm-framework.py"
echo "    Read: $PMM_QA_DIR/qa-integration/pmm_qa/README.md"

echo "Workspace ready: $PMM_DIR + $PMM_QA_DIR"
