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
| **ORCHESTRATOR_API_KEY** | You (scripts) + Jira webhook | Protects `/loop/api/*` and validates `x-api-key` on manual transitions. Jira Automation sends the same value in `x-webhook-secret` (or configure header to match). |
| **GITHUB_TOKEN** | Orchestrator + agents | Clone repos, search pmm-submodules PRs, open PRs. |
| **LINODE_TOKEN** | Orchestrator | Create/delete ephemeral QA worker VMs. Same token as Terraform, or a scoped sub-token. |
| **JIRA_API_TOKEN** | Orchestrator | Post comments (conversation link, PMM URL) to tickets. |

## Public URL

POC uses **bare Linode IP + HTTPS**:

```text
https://139.162.150.187/
```

Caddy terminates TLS with a **self-signed cert** (`tls internal`). Accept the browser warning on first visit.

Bootstrap sets `AGENT_CANVAS_PUBLIC_URL=https://<ip>` automatically. No sslip.io, no custom domain until you want one.

## Token links

| What | Where |
|------|-------|
| Linode API token | https://cloud.linode.com/profile/tokens |
| GitHub PAT | https://github.com/settings/tokens (`repo` scope) |
| Jira API token | https://id.atlassian.com/manage-profile/security/api-tokens |

## LLM providers (no LiteLLM)

This stack does **not** run LiteLLM. Configure models in **Agent Canvas → Manage Backends**:

- **GitHub Copilot:** use Copilot CLI with `--acp` (Agent Client Protocol) — Canvas talks to it directly.
- **Cursor:** there is no first-class “paste Cursor API token” backend in Agent Canvas today. Options: use Copilot/Anthropic/OpenAI via ACP or OpenAI-compatible API; run Cursor IDE locally for your own sessions; or wire [Cursor Cloud Agents API](https://cursor.com/docs) separately if you build a custom backend adapter.

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

Copy from `terraform.tfvars.example`. **Never commit `terraform.tfvars`.**

After apply:

```text
https://<terraform output public_ip>/
Jira webhook: https://<ip>/hooks/jira
Test API:     https://<ip>/loop/api/tickets  (header x-api-key)
```
