# Agent Canvas

Agent Canvas runs on **chat runner VMs** (`:8000`), not on the control plane.

Install follows [OpenHands VM / Self-Hosted](https://docs.openhands.dev/openhands/usage/agent-canvas/backend-setup/vm) via `deploy/install-runner.sh` + `deploy/bootstrap-runner.sh`.

Secrets: `/etc/pmm-agentic-flow/runner.env` (cloud-init per ticket).

## Open

Link is posted in Jira when the orchestrator provisions the runner:

```text
http://<runner-ip>:8000/
```

API key: same `agent_canvas_api_key` from terraform (injected into runner env).

## LLM backends

Cursor CLI installs to `/usr/local/bin/agent` on runner bootstrap. See [llm-acp.md](./llm-acp.md).

## Sandboxes

**No Docker** — each ticket gets a dedicated Linode VM. The VM is the sandbox; Agent Canvas runs as a host process (`process` provider / VM mode).

## Troubleshooting (on runner)

```bash
journalctl -u agent-canvas -n 80 --no-pager
systemctl status agent-canvas
```

Control plane orchestrator:

```bash
journalctl -u orchestrator -n 80 --no-pager
```

## Re-deploy control plane

```bash
cd /opt/pmm-agentic-flow/src && git pull
bash deploy/bootstrap-host.sh
```

Runners are ephemeral — reprovision by re-triggering a Jira transition or destroying/recreating the ticket phase.
