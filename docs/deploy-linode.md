# Deploying on Linode

Terraform **creates the server**. **npm + systemd** run the stack on the VM (OpenHands VM install guide).

```text
Your laptop                         Linode VM (Ubuntu 24.04)
─────────────                       ─────────────────────────
terraform apply  ───────────────►    cloud-init:
                                     1. Node 22 + uv + Docker (sandboxes only)
                                     2. write /etc/pmm-agentic-flow/env  ← from tfvars
                                     3. git clone this repo
                                     4. deploy/bootstrap-host.sh
                                           ├── agent-canvas.service  → :8000 (npm)
                                           └── orchestrator.service  → :8080
```

**No `.env` on your PC.** Only `terraform/terraform.tfvars`.

Docker on the host is **only** for per-chat sandboxes (Agent Canvas Docker sandbox provider). The Canvas and orchestrator processes run natively on the VM.

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
bash deploy/bootstrap-host.sh
```

Re-run `terraform apply` when you change tfvars or cloud-init.

---

## QA workers

Workers use the same **npm Agent Canvas on the VM** pattern. The orchestrator provisions a Linode per pool slot (up to `chats_per_worker` in `config/stack.yaml`). Each QA ticket gets a **separate chat**; each chat spawns its own **Docker sandbox** on the worker. PMM server runs as one shared container per worker (`:8443`).

See [pmm-architecture.md](./pmm-architecture.md) and [sandbox-lifecycle.md](./sandbox-lifecycle.md).
