# Jira — REST API only (no MCP)

Percona does **not** authorize Atlassian Rovo MCP API tokens. Do not configure or use Jira MCP in Agent Canvas.

## Credentials on the control plane

| File | Who can read |
|------|----------------|
| `/etc/pmm-agentic-flow/env` | root only (orchestrator, systemd) |
| `/etc/pmm-agentic-flow/jira.env` | `agentcanvas` — JIRA_BASE_URL, JIRA_EMAIL, JIRA_API_TOKEN |

Created by `deploy/install-jira-agent-env.sh` during bootstrap. Re-run after tfvars change:

```bash
sudo bash /opt/pmm-agentic-flow/src/deploy/install-jira-agent-env.sh
```

Terraform tfvars → full env on VM; Jira subset copied to `jira.env` for the agent shell.

## Fetch an issue (agent)

```bash
# As agentcanvas or any user in group agentcanvas — no sudo
bash /opt/pmm-agentic-flow/jira-issue.sh PMM-15167
bash /opt/pmm-agentic-flow/src/scripts/jira-issue.sh PMM-15167 summary,description,status
```

## Manual curl (root only — env is mode 600)

```bash
sudo bash -c 'source /etc/pmm-agentic-flow/env && AUTH=$(printf "%s:%s" "$JIRA_EMAIL" "$JIRA_API_TOKEN" | base64 -w0) && curl -sS -H "Authorization: Basic $AUTH" -H "Accept: application/json" "$JIRA_BASE_URL/rest/api/3/issue/PMM-15167"'
```

## What not to do

- Do not scrape Jira in the browser.
- Do not install Atlassian Rovo MCP (`mcp.atlassian.com`).
- Webhook transitions still come from Jira Automation → orchestrator (`POST /hooks/jira`).

Issue context for prompts is also injected by the orchestrator on transition; use the API when you need fresh fields mid-conversation.
