# Secrets and API keys

## Generate random keys (PowerShell)

```powershell
-join ((48..57) + (65..90) + (97..122) | Get-Random -Count 32 | ForEach-Object {[char]$_})
```

Run three times: `agent_canvas_api_key`, `agent_canvas_secret_key`, `orchestrator_api_key`.

## What each key does

| Key | Who uses it | Purpose |
|-----|-------------|---------|
| **AGENT_CANVAS_API_KEY** | You (browser) + orchestrator | Protects the Agent Canvas UI/API when exposed on the internet. Enter once in the Canvas login/settings. Orchestrator sends it when creating conversations. |
| **AGENT_CANVAS_SECRET_KEY** | Agent Canvas only | Encrypts secrets the Canvas stores on disk (provider tokens, settings). Not sent on every request — set once at deploy. |
| **ORCHESTRATOR_API_KEY** | You (scripts) + Jira webhook | Protects `https://<ip>/orchestrator/*` and validates `x-api-key`. |
| **GITHUB_TOKEN** | Orchestrator + agents | Clone repos, PRs. |
| **github_copilot_token** (tfvars) | Copilot CLI in agent-canvas | ACP backend. |
| **cursor_api_key** (tfvars) | Cursor CLI in agent-canvas | ACP backend. |
| **LINODE_TOKEN** | Orchestrator | Ephemeral QA worker VMs. |
| **JIRA_API_TOKEN** | Orchestrator | Post comments (conversation link, PMM URL) to tickets. |

## Public URL

POC uses **bare Linode IP + HTTP**:

```text
http://<public_ip>:8000/
```

Cloud-init sets `AGENT_CANVAS_PUBLIC_URL=http://<ip>:8000` automatically.

## Token links

| What | Where |
|------|-------|
| Linode API token | https://cloud.linode.com/profile/tokens |
| GitHub PAT | https://github.com/settings/tokens (`repo` scope) |
| Jira API token | https://id.atlassian.com/manage-profile/security/api-tokens |

## LLM providers

| Goal | Path |
|------|------|
| Chat interativo no Canvas | Settings → LLM (Anthropic/OpenAI) **ou** ACP — ver [llm-acp.md](./llm-acp.md) |
| **Cursor subscrição, sem ACP no UI** | **Cloud Agents REST API** — ver [cursor-api.md](./cursor-api.md) |
| Verificar CLIs na VM | `docker exec agent-canvas ls -la /usr/local/bin/agent` |

This stack does **not** run LiteLLM. Cursor API key does **not** go in Settings → LLM.

## Team deployment (not POC)

For a shared team setup, use **service accounts**, not personal tokens:

| Service | POC (you) | Team |
|---------|-----------|------|
| GitHub | Your PAT | Machine user / GitHub App with org install |
| Jira | Your API token | Bot/service account + scoped API token |
| Linode | Your token | Project-scoped token or separate sub-account |
| LLM | Your Copilot/Cursor | Org subscription + dedicated credentials |

Personal tokens work for a solo POC; production needs identities that survive people leaving the team.

## Example `terraform.tfvars`

Copy from `terraform/terraform.tfvars.example`. **Never commit `terraform.tfvars`.**

This is the **only** secrets file on your PC. Cloud-init writes `/etc/pmm-agentic-flow/env` on the VM.

After apply:

```text
http://<terraform output public_ip>:8000/
Jira webhook: http://<ip>:8080/hooks/jira
```
