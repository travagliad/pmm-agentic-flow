# PMM — how the loop maps to real repos

This repo is **not** PMM. It is the **orchestration platform** (Linode + OpenHands + LiteLLM).

Product and QA code stay in their own repositories. The loop coordinates agents, sandboxes, and Jira status transitions.

## What runs on Linode (always on)

```text
docker compose up
  ├── Caddy          → https://loop.your-domain.com
  ├── OpenHands      → UI + API (port 3000 internal)
  ├── LiteLLM        → Copilot as the model
  └── Orchestrator   → Jira webhooks + status sync (future)
```

OpenHands stays running after deploy. Each ticket gets **one long-lived conversation** and **one sandbox** until Ready for Merge.

## Repos involved

| Repo | Role | Agent |
|------|------|-------|
| `percona/pmm` | Server / API / managed code + OpenSpec | **Dev** (`/opsx:apply`) |
| `percona/grafana` | Grafana UI (some tickets) | **Dev** when applicable |
| `percona/pmm-qa` | Playwright E2E, CLI, integration | **QA** (`/loop:qa`) |
| `Percona-Lab/pmm-submodules` | FB build images | Orchestrator (read-only) |
| `Percona-Lab/jenkins-pipelines` | AWS staging (optional) | Orchestrator (optional) |

OpenSpec lives in the **dev repo** (`openspec/changes/<id>/`).

## Environment setup (PMM-specific)

Most `pmm-qa` CI jobs assume **`pmm-framework.py`** (`qa-integration/`) has already provisioned PMM Client + monitored DBs on the Docker network `pmm-qa`. See `percona/pmm-qa` `AGENTS.md`.

| Mode | When | How |
|------|------|-----|
| **pmm-framework** | POC / CI-parity in sandbox | Run `qa-integration/pmm-framework.py` once when entering In Progress |
| **Jenkins staging** | Full AWS parity | `pmm3-aws-staging-start` with FB image params |
| **External** | Staging already exists | Pass `PMM_SERVER_URL` |

The sandbox is **not torn down** between Dev↔QA iterations inside In Progress / In QA. Teardown happens at **Ready for Merge**.

## QA suites (`pmm-qa`)

| Ticket type | Suite path | Runner |
|-------------|------------|--------|
| Grafana / admin UI | `e2e_tests/` | `runner-e2e-tests-playwright.yml` |
| pmm-admin CLI | `cli/` | `runner-integration-cli-tests.yml` |
| Client + DB integration | `qa-integration/` + framework | `runner-integration-cli-tests.yml` |

QA agent may **only** edit paths under `pmm-qa`. Dev agent may **not** edit test suites.

## Gaps in the current scaffold

| Gap | Impact |
|-----|--------|
| Jira webhook → OpenSpec commands | Not wired yet |
| FB image resolution from pmm-submodules | Manual today |
| Jenkins API integration | Optional for POC |
| Shared / multi-user conversation UX | Depends on OpenHands version + auth |
| PR link back to Jira | Orchestrator comment automation |

See [workflow.md](./workflow.md) for the full Jira ↔ OpenSpec ↔ agent mapping.
