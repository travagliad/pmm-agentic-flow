#!/usr/bin/env bash
# Reset one ticket: orchestrator state, workspace, GitHub PRs/branches, QA runner Linode.
# Usage: sudo bash deploy/reset-ticket.sh PMM-15167
set -euo pipefail

TICKET="${1:?usage: reset-ticket.sh PMM-15167}"
TICKET_UP="$(echo "$TICKET" | tr '[:lower:]' '[:upper:]')"
BRANCH="$TICKET_UP"
DEST="${PMM_AGENTIC_FLOW_SRC:-/opt/pmm-agentic-flow/src}"
LEGACY_BRANCH="agent/${TICKET_UP}-rta-real-time-query-analytics-for-postgr"

ENV_FILE="/etc/pmm-agentic-flow/env"
AGENT_ENV="/etc/pmm-agentic-flow/agent-shell.env"
for f in "$ENV_FILE" "$AGENT_ENV"; do
  if [ -f "$f" ]; then
    set -a
    # shellcheck source=/dev/null
    source "$f"
    set +a
  fi
done

echo "[reset-ticket] $TICKET_UP"

echo "[reset-ticket] orchestrator ticket JSON"
rm -f "/var/lib/pmm-agentic-flow/orchestrator/tickets/${TICKET_UP}.json"

echo "[reset-ticket] agent state"
rm -f /projects/.agent/state.json

run_gh() {
  if id agentcanvas >/dev/null 2>&1; then
    runuser -u agentcanvas -- env HOME=/home/agentcanvas PATH="/usr/local/bin:/usr/bin:/bin" \
      GITHUB_TOKEN="${GITHUB_TOKEN:-}" gh "$@"
  elif [ -n "${GITHUB_TOKEN:-}" ]; then
    gh "$@"
  else
    echo "[reset-ticket] WARN: no gh token — skip GitHub cleanup" >&2
    return 1
  fi
}

github_cleanup() {
  local repo head pr
  for repo in percona/pmm Percona-Lab/pmm-submodules; do
    for head in "$BRANCH" "$LEGACY_BRANCH"; do
      pr="$(run_gh pr list --repo "$repo" --head "$head" --json number -q '.[0].number' 2>/dev/null || true)"
      if [ -n "$pr" ] && [ "$pr" != "null" ]; then
        echo "[reset-ticket] close $repo PR #$pr (head $head)"
        run_gh pr close "$pr" --repo "$repo" --delete-branch 2>/dev/null || \
          run_gh pr close "$pr" --repo "$repo" 2>/dev/null || true
      fi
    done
    if [ "$repo" = "Percona-Lab/pmm-submodules" ]; then
      pr="$(run_gh pr list --repo "$repo" --search "$TICKET_UP in:title" --state open --json number -q '.[0].number' 2>/dev/null || true)"
      if [ -n "$pr" ] && [ "$pr" != "null" ]; then
        echo "[reset-ticket] close $repo PR #$pr (search title)"
        run_gh pr close "$pr" --repo "$repo" 2>/dev/null || true
      fi
    fi
  done
  for head in "$BRANCH" "$LEGACY_BRANCH"; do
    run_gh api -X DELETE "repos/percona/pmm/git/refs/heads/${head}" 2>/dev/null || true
  done
}

github_cleanup || true

reset_git_repo() {
  local dir="$1"
  shift
  local delete_branches="$*"
  if [ ! -d "$dir/.git" ]; then
    echo "[reset-ticket] SKIP $dir (not a git repo)"
    return 0
  fi
  echo "[reset-ticket] reset $dir → main (discard all local changes)"
  runuser -u agentcanvas -- env DELETE_BRANCHES="$delete_branches" REPO_DIR="$dir" \
    PATH="/usr/local/bin:/usr/bin:/bin" bash -lc '
    set -e
    cd "$REPO_DIR"
    git fetch origin
    git reset --hard
    git clean -fd
    git checkout -f main
    git reset --hard origin/main
    for b in $DELETE_BRANCHES; do
      [ -n "$b" ] && git branch -D "$b" 2>/dev/null || true
    done
  '
}

echo "[reset-ticket] pmm workspace → main"
if id agentcanvas >/dev/null 2>&1; then
  reset_git_repo /projects/pmm "$BRANCH" "$LEGACY_BRANCH"
  reset_git_repo /projects/pmm-qa
fi

echo "[reset-ticket] pmm-framework teardown (if any)"
if [ -f /projects/pmm-qa/qa-integration/pmm-framework.py ]; then
  python3 /projects/pmm-qa/qa-integration/pmm-framework.py --destroy 2>/dev/null || true
fi

echo "[reset-ticket] QA runner Linode"
if [ -n "${LINODE_TOKEN:-}" ]; then
  LABEL="run-$(echo "$TICKET_UP" | tr '[:upper:]' '[:lower:]')"
  IDS="$(curl -fsSL -H "Authorization: Bearer $LINODE_TOKEN" \
    -H "X-Filter: {\"+and\":[{\"label\":\"$LABEL\"}]}" \
    "https://api.linode.com/v4/linode/instances" | jq -r '.data[].id // empty' 2>/dev/null || true)"
  for id in $IDS; do
    echo "[reset-ticket] delete Linode $id ($LABEL)"
    curl -fsSL -X DELETE -H "Authorization: Bearer $LINODE_TOKEN" \
      "https://api.linode.com/v4/linode/instances/$id" || true
  done
fi

echo "[reset-ticket] optional: wipe Canvas conversations"
echo "  systemctl stop agent-canvas"
echo "  rm -rf /home/agentcanvas/.openhands/storage/*"
echo "  systemctl start agent-canvas"

echo "[reset-ticket] done — restart flow: simulate Ready for Refinement"
echo "  Jira: move $TICKET_UP to Ready for Refinement"
