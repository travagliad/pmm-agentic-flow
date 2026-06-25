# Agent Canvas

Stack: **agent-canvas** on `:8000` + **orchestrator** on `:8080`. Runs on the Linode VM only — **npm + systemd**, not Docker Compose.

Install follows [OpenHands VM / Self-Hosted](https://docs.openhands.dev/openhands/usage/agent-canvas/backend-setup/vm).

Secrets: `/etc/pmm-agentic-flow/env` (from `terraform.tfvars` via cloud-init).

## Open

```text
http://<linode-ip>:8000/
```

API key: `grep LOCAL_BACKEND_API_KEY /etc/pmm-agentic-flow/env`

## LLM backends

Cursor CLI installs to `/usr/local/bin/agent` on host bootstrap. See [llm-acp.md](./llm-acp.md).

## Sandboxes

Each conversation/chat spawns an isolated **Docker sandbox** on the host (Canvas Docker provider). Dev chats run on the control plane; QA chats run on worker VMs.

## Troubleshooting

```bash
journalctl -u agent-canvas -n 80 --no-pager
journalctl -u orchestrator -n 80 --no-pager
systemctl status agent-canvas orchestrator
```

## Re-deploy after git pull

```bash
cd /opt/pmm-agentic-flow/src && git pull
bash deploy/bootstrap-host.sh
```
