# PMM Agentic Flow

Spec-driven PMM automation on a **Linode VM** — not on your laptop.

---

## Do not run the stack locally

The control plane is provisioned by **Terraform on Linode** only. See [docs/GETTING-STARTED.md](./docs/GETTING-STARTED.md).

---

## Ready to test? Start here

**[docs/tokens-and-secrets.md](./docs/tokens-and-secrets.md)** — fill `terraform/terraform.tfvars`

**[docs/GETTING-STARTED.md](./docs/GETTING-STARTED.md)** — checklist from zero to first ticket.

**[docs/deploy-linode.md](./docs/deploy-linode.md)** — Terraform details.

```powershell
cd terraform
copy terraform.tfvars.example terraform.tfvars   # fill secrets
terraform init
terraform apply
```

Open `http://<public_ip>:8000/` after cloud-init (~5 min).

---

## Docs

| Doc | Contents |
|-----|----------|
| [GETTING-STARTED.md](./docs/GETTING-STARTED.md) | Checklist — deploy on Linode |
| [deploy-linode.md](./docs/deploy-linode.md) | Terraform, cloud-init, updates |
| [llm-acp.md](./docs/llm-acp.md) | Cursor/Copilot CLIs via Terraform |
| [terraform-variables.md](./docs/terraform-variables.md) | All tfvars reviewed |
| [architecture-faq.md](./docs/architecture-faq.md) | systemd, Docker, orchestrator, ngrok |

---

## After Linode is up

```bash
export JIRA_WEBHOOK_SECRET=<api_secret from terraform.tfvars>
./scripts/simulate-transition.sh PMM-14915 "Ready for Refinement" "Test"
```

Agent Canvas: `http://<public_ip>:8000/` — see [docs/agent-canvas.md](docs/agent-canvas.md).
