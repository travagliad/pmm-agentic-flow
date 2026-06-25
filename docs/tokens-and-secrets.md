# Secrets and API keys

Full variable review: [terraform-variables.md](./terraform-variables.md).

## Generate random keys (PowerShell)

```powershell
-join ((48..57) + (65..90) + (97..122) | Get-Random -Count 32 | ForEach-Object {[char]$_})
```

Generate **three** values for `terraform.tfvars`:

| tfvars key | Purpose |
|------------|---------|
| `agent_canvas_api_key` | Canvas UI + orchestrator → Canvas API |
| `agent_canvas_secret_key` | Encrypt Canvas settings on disk |
| `api_secret` | Orchestrator REST (`x-api-key`) + Jira webhook (`x-webhook-secret`) |

## What each key does

| Key | Who uses it | Purpose |
|-----|-------------|---------|
| **agent_canvas_api_key** | Browser, orchestrator | `LOCAL_BACKEND_API_KEY` — Canvas `--public` mode |
| **agent_canvas_secret_key** | Agent Canvas | `OH_SECRET_KEY` — at-rest encryption |
| **api_secret** | `simulate-transition.sh`, Jira | Same value: `x-api-key` on `/orchestrator/*`, `x-webhook-secret` on `/hooks/jira` |
| **github_token** | Orchestrator, agents | Clone repos, PRs |
| **github_copilot_token** | Copilot CLI | ACP (optional) |
| **cursor_api_key** | Cursor CLI | ACP (optional) |
| **linode_token** | Orchestrator | QA worker VMs |
| **jira_api_token** | Orchestrator | Post comments to Jira |

## Public URL

With ngrok (recommended):

```hcl
ngrok_domain = "https://your-app.ngrok-free.app"
```

Without ngrok: `terraform output app_url` → `http://<ip>:8000/`

## After apply

```text
Canvas:  terraform output app_url
Webhook: terraform output jira_webhook_url
```

Simulate transition from your PC:

```powershell
$env:JIRA_WEBHOOK_SECRET = "<api_secret from tfvars>"
$env:ORCHESTRATOR_BASE_URL = "https://your-app.ngrok-free.app/orchestrator"
bash ./scripts/simulate-transition.sh PMM-123 "In Progress"
```

(`ORCHESTRATOR_API_KEY` works too — same value on the VM.)

## Team deployment

Use service accounts for GitHub/Jira/Linode in production — not personal PATs. See [architecture-faq.md](./architecture-faq.md).
