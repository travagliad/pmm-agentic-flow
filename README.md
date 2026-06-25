# PMM Agentic Flow

Spec-driven PMM automation on a **Linode VM** — not on your laptop.

---

## Do not run Docker locally

```bash
# WRONG — stack runs on Linode only
cd deploy && docker compose up -d --build
```

If you already did: [docs/GETTING-STARTED.md](./docs/GETTING-STARTED.md#if-you-already-ran-it-locally-by-mistake)

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
| [workflow.md](./docs/workflow.md) | Jira ↔ OpenSpec ↔ agents |

---

## After Linode is up

```bash
export ORCHESTRATOR_API_KEY=<from terraform.tfvars>
./scripts/simulate-transition.sh PMM-14915 "Ready for Refinement" "Test"
```

Agent Canvas: `http://<public_ip>:8000/` — see [docs/agent-canvas.md](docs/agent-canvas.md).
