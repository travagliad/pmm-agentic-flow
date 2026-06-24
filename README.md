# PMM Agentic Flow

Spec-driven PMM automation on a **Linode VM** — not on your laptop.

---

## ⚠️ Do not run Docker locally

**Never** run this on your PC for the real setup:

```bash
# WRONG for production / POC testing — installs on YOUR machine
cp .env.example .env
cd deploy && docker compose up -d --build
```

If you already did: [docs/GETTING-STARTED.md](./docs/GETTING-STARTED.md#if-you-already-ran-it-locally-by-mistake)

---

## Ready to test? Start here

**[docs/tokens-and-secrets.md](./docs/tokens-and-secrets.md)** — **token links + fill terraform.tfvars (no domain OK)**

**[docs/GETTING-STARTED.md](./docs/GETTING-STARTED.md)** — checklist from zero to first ticket.

**[docs/deploy-linode.md](./docs/deploy-linode.md)** — Terraform + DNS details.

Quick summary:

```powershell
# 1. Push repo to GitHub
# 2. On your PC:
cd terraform
copy terraform.tfvars.example terraform.tfvars   # fill secrets + bootstrap_repo_url
terraform init
terraform apply

# 3. DNS A record → terraform output public_ip
# 4. Browser → https://loop.yourdomain.com/
```

The Linode stays on. Your PC is only needed for `terraform apply` and opening the browser.

---

## Docs

| Doc | Contents |
|-----|----------|
| [GETTING-STARTED.md](./docs/GETTING-STARTED.md) | **Checklist** — fix local mistake + deploy |
| [deploy-linode.md](./docs/deploy-linode.md) | Terraform, cloud-init, updates |
| [workflow.md](./docs/workflow.md) | Jira ↔ OpenSpec ↔ agents |
| [pmm-architecture.md](./docs/pmm-architecture.md) | pmm + pmm-qa repos |

---

## After Linode is up

```bash
export LOOP_BASE_URL=https://loop.yourdomain.com
export ORCHESTRATOR_API_KEY=<from terraform.tfvars>
./scripts/simulate-transition.sh PMM-14915 "Ready for Refinement" "Test"
```

Or use the OpenHands UI at `https://loop.yourdomain.com/`.
