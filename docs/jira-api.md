# Jira — REST API via curl (no MCP, no helper script)

Percona does **not** authorize Atlassian Rovo MCP. The agent uses **curl** with `JIRA_*` from the Canvas process environment (injected by systemd from `/etc/pmm-agentic-flow/env`).

## Fetch issue (agent shell)

```bash
curl -sS -u "${JIRA_EMAIL}:${JIRA_API_TOKEN}" \
  -H "Accept: application/json" \
  "${JIRA_BASE_URL}/rest/api/3/issue/PMM-15167?fields=summary,description,status,issuetype"
```

Save and parse ADF description with Python if needed (see agent conversation examples).

## If JIRA_* is empty in shell

The `agent-canvas` service loads env via systemd. Non-interactive subshells should still inherit it. If not:

```bash
set -a && source /etc/pmm-agentic-flow/agent-shell.env && set +a
```

(`deploy/install-jira-agent-env.sh` writes `agent-shell.env` — run once as root after bootstrap.)

## What not to do

- Do not use Jira MCP or browser scraping.
- Do not use `sudo` — agent has no root password.

Webhook transitions still inject summary/description in orchestrator prompts.
