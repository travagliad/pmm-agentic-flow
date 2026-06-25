# Jira — REST API only (no MCP)

Percona does **not** authorize Atlassian Rovo MCP API tokens. Do not configure or use Jira MCP in Agent Canvas.

## Credentials on the control plane

From `terraform/terraform.tfvars` → `/etc/pmm-agentic-flow/env`:

| Variable | Use |
|----------|-----|
| `JIRA_BASE_URL` | e.g. `https://perconadev.atlassian.net` |
| `JIRA_EMAIL` | Atlassian account email |
| `JIRA_API_TOKEN` | Classic Jira API token (id.atlassian.com) |

The orchestrator already uses these for comments. The **agent** should use the same via `curl` or the helper script.

## Fetch an issue (agent)

```bash
# Full issue JSON
bash /opt/pmm-agentic-flow/src/scripts/jira-issue.sh PMM-15167

# Selected fields only
bash /opt/pmm-agentic-flow/src/scripts/jira-issue.sh PMM-15167 summary,description,status
```

## Manual curl

```bash
source /etc/pmm-agentic-flow/env
AUTH=$(printf '%s:%s' "$JIRA_EMAIL" "$JIRA_API_TOKEN" | base64 -w0)

curl -sS -H "Authorization: Basic $AUTH" -H "Accept: application/json" \
  "$JIRA_BASE_URL/rest/api/3/issue/PMM-15167"
```

## What not to do

- Do not scrape Jira in the browser.
- Do not install Atlassian Rovo MCP (`mcp.atlassian.com`).
- Webhook transitions still come from Jira Automation → orchestrator (`POST /hooks/jira`).

Issue context for prompts is also injected by the orchestrator on transition; use the API when you need fresh fields mid-conversation.
