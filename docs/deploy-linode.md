# Deploying on Linode

Terraform **creates the server**. Docker Compose **runs on that server only**.

```text
Your laptop                         Linode VM (Ubuntu 24.04)
─────────────                       ─────────────────────────
terraform apply  ───────────────►    cloud-init:
                                     1. install Docker
                                     2. write /etc/pmm-agentic-flow/env  ← from tfvars
                                     3. git clone this repo
                                     4. docker compose --env-file /etc/pmm-agentic-flow/env up -d
                                           ├── agent-canvas (:8000)
                                           └── orchestrator (:8080)
```

**No `.env` on your PC.** Only `terraform/terraform.tfvars`.

---

## Prerequisites

1. Push this repo to GitHub (cloud-init clones it on first boot).
2. Linode API token with Linode read/write + Firewall.
3. Secrets in `terraform/terraform.tfvars` (see `terraform.tfvars.example`).

---

## Apply

```powershell
cd terraform
copy terraform.tfvars.example terraform.tfvars
terraform init
terraform apply
terraform output public_ip
```

---

## Updates after code changes

```bash
ssh root@<public_ip>
cd /opt/pmm-agentic-flow/src && git pull
cd deploy
docker compose --env-file /etc/pmm-agentic-flow/env up -d --build
```

Re-run `terraform apply` when you change tfvars or cloud-init.
