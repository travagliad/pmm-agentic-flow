# Getting started — Terraform only

Everything runs on **Linode**. Your PC only runs `terraform apply`.

See [architecture-faq.md](./architecture-faq.md) for systemd vs OpenHands tmux, runner-per-chat model, orchestrator role, ngrok, and what end users need.

---

## Checklist

### A. One-time prep (your PC)

- [ ] Push this repo to GitHub (`bootstrap_repo_url` in tfvars)
- [ ] Linode API token
- [ ] Fill `terraform/terraform.tfvars` from `terraform.tfvars.example` — see [tokens-and-secrets.md](./tokens-and-secrets.md)
- [ ] **Recommended:** `ngrok_authtoken` + `ngrok_domain` (stable HTTPS URL)
- [ ] **Recommended:** `admin_cidrs = ["YOUR.PUBLIC.IP/32"]` (SSH only)

### B. Deploy

```powershell
cd terraform
copy terraform.tfvars.example terraform.tfvars
terraform init
terraform apply
terraform output next_steps
terraform output app_url
```

Wait ~8 minutes for cloud-init (orchestrator + optional ngrok).

### C. First ticket (users)

1. Move a Jira ticket to **Ready for Refinement** (or use simulate script)
2. Orchestrator provisions a runner — **Canvas URL appears in Jira comments**
3. Open the runner URL in browser; enter `agent_canvas_api_key` from tfvars
4. Settings → Agent → ACP: `/usr/local/bin/agent` + `acp` (if using Cursor)

No install required for dev/QA/PO — browser only.

### D. Jira webhook

Use `terraform output jira_webhook_url` (with ngrok: `https://<domain>/hooks/jira`).

### E. Test without Jira

```powershell
$env:JIRA_WEBHOOK_SECRET = "<api_secret from tfvars>"
$env:ORCHESTRATOR_BASE_URL = "http://<ip>:8080/orchestrator"
bash ./scripts/simulate-transition.sh PMM-14915 "Ready for Refinement" "Test"
```

---

## What runs where

| Component | Where |
|-----------|--------|
| Orchestrator (Node, systemd) | Control plane Linode |
| Agent Canvas (`npm`, systemd) | One runner Linode per ticket |
| Terraform | Your PC |
| Users | Browser → runner URL from Jira |

---

## Troubleshooting

| Problem | Check |
|---------|--------|
| apply OK but URL down | Wait full 8–10 min; cloud-init log on VM: `/var/log/pmm-agentic-flow-bootstrap.log` |
| Canvas asks API key | `agent_canvas_api_key` from tfvars |
| ngrok not working | `ngrok_authtoken` + `ngrok_domain` both set; `systemctl status ngrok` on VM |

Re-apply after tfvars change: `terraform apply` (cloud-init only on first boot; for code updates push to git and re-run apply or SSH once to `git pull && bash deploy/bootstrap-host.sh`).

See [deploy-linode.md](./deploy-linode.md), [agent-canvas.md](./agent-canvas.md).
