# Sandbox lifecycle

## 2 containers (like pmm-server — no reverse proxy)

| Container | Port | URL |
|-----------|------|-----|
| `agent-canvas` | 8000 | **http://\<ip\>:8000/** |
| `orchestrator` | 8080 | http://\<ip\>:8080/hooks/jira |

No Caddy, no TLS, no cert warnings. POC only — add HTTPS when you have a domain.

## Update Linode

```bash
cd /opt/pmm-agentic-flow/src && git pull
bash scripts/linode-recover.sh
```

Firewall (Linode Cloud + ufw): **TCP 8000** and **8080**.

## Instance sizes

`config/stack.yaml` → `infrastructure.linode` (4GB control, 8GB QA worker).

## Test without Jira

```bash
export ORCHESTRATOR_API_KEY=...
export ORCHESTRATOR_BASE_URL=http://<ip>:8080/orchestrator
./scripts/simulate-transition.sh PMM-15083 "In Progress"
```

Optional LLM CLIs: `bash scripts/install-agent-clis.sh` — not required for the UI.
