---
marp: true
theme: default
class: invert
paginate: false
backgroundColor: #090b0f
color: #adbac7
style: |
  section {
    font-family: -apple-system, BlinkMacSystemFont, 'Inter', 'Segoe UI', sans-serif;
    padding: 56px 84px !important;
    font-size: 22px;
    display: flex;
    flex-direction: column;
    justify-content: flex-start;
    align-items: stretch;
    background: #090b0f !important;
  }
  h1 {
    color: #f0f6fc !important;
    font-size: 1.55em !important;
    font-weight: 700;
    letter-spacing: -0.03em;
    margin-top: 0px !important;
    margin-bottom: 24px !important;
    padding-left: 15px;
    border-left: 4px solid #58a6ff !important;
    line-height: 1.2;
  }
  h2 {
    color: #58a6ff !important;
    font-size: 1.05em !important;
    font-weight: 500;
    letter-spacing: -0.01em;
    margin-top: 0px !important;
    margin-bottom: 26px !important;
  }
  h3 { color: #8b949e !important; font-weight: 600; font-size: 0.9em !important; margin: 0 0 8px; }
  ul { margin-top: 6px; padding-left: 0px; list-style-type: none !important; }
  li { margin-bottom: 15px; line-height: 1.5; color: #adbac7 !important; position: relative; padding-left: 20px; }
  li::before { content: "▸"; color: #58a6ff; font-weight: bold; display: inline-block; width: 1em; margin-left: -1em; }
  li li { margin-bottom: 5px; font-size: 0.92em; }
  li li::before { content: "·"; color: #6e7681; }
  strong { color: #f0f6fc !important; font-weight: 600; }
  em { color: #c9d1d9; font-style: italic; }
  code { background: #161b22; color: #79c0ff; padding: 1px 6px; border-radius: 4px; font-size: 0.85em; }
  a { color: #58a6ff; }
  img { display: block; margin: 6px auto; }
  blockquote {
    border-left: 3px solid #58a6ff; background: #0f141b; padding: 11px 18px; margin: 8px 0;
    border-radius: 0 6px 6px 0; color: #c9d1d9; font-size: 0.82em;
  }
  blockquote strong { color: #58a6ff !important; }
  table { border-collapse: collapse; width: 100%; font-size: 0.76em; background: #0d1117; }
  th { color: #f0f6fc; text-align: left; background: #161b22; border-bottom: 2px solid #30363d; padding: 9px 11px; font-weight: 600; }
  td { background: #0d1117; border-bottom: 1px solid #21262d; padding: 9px 11px; color: #c9d1d9; vertical-align: top; }
  td strong { color: #f0f6fc; }
  tr:first-child th:first-child { color: #8b949e; }
  footer, section::after { color: #56606b; font-size: 0.62em; }
  section.tight { font-size: 19px; }
  section.tight li { margin-bottom: 9px; }
  section.diagram { justify-content: flex-start; }
  section.lead { justify-content: center; align-items: center; text-align: center; }
  section.lead h1 { font-size: 2.3em !important; border-left: none !important; padding-left: 0; margin-bottom: 12px; }
  section.lead h2 { color: #adbac7 !important; font-weight: 400; font-size: 1.0em !important; margin-bottom: 22px; }
  section.lead h3 { color: #58a6ff !important; font-size: 0.82em !important; letter-spacing: 0.05em; }
  section.lead p { color: #6e7681; font-size: 0.8em; max-width: 30em; }

---

<!--
Diagrams: ./assets/*.svg (copy from design repo if missing).
Export PDF:  npx @marp-team/marp-cli@latest docs/presentation.md -o deck.pdf --allow-local-files
-->

<!-- class: invert lead -->
<!-- footer: '' -->

# PMM Agentic Flow

## Spec-driven generation · Linode sandboxes · QA built in

From a refined **PMM** ticket to reviewed PRs — with a warm test environment for manual exploration.

---

<!-- class: invert -->
<!-- paginate: true -->

# Agenda

- What we built in the POC (vs the original vision)
- Reference architecture — control plane on Linode
- Orchestrator + Agent Canvas — roles and LLM path
- Two agents — Dev builder and QA verifier
- Jira lifecycle — PMM statuses
- QA — Playwright in `pmm-qa`
- Deploy model, gaps, next steps

---

# The Shift (unchanged intent)

<!-- _class: tight -->

| Today | Target |
| --- | --- |
| Hand-writing boilerplate and glue code | **Authoring specs** and reviewing intent |
| Requirements buried in chat history | **Spec-as-code** in `percona/pmm` |
| "Works on my machine" verification | **Ephemeral workers** + warm control-plane sandbox |
| PRs from static diffs only | PRs backed by **traces, video, live PMM URL** |
| QA as a downstream phase | **QA in the same loop**, suite in `pmm-qa` |

> **Principle** — humans at two gates: spec approval and PR review. The platform runs on **Linode**, not developer laptops.

---

# What Changed in the POC (scope reality)

<!-- _class: tight -->

| Original deck | **What we shipped** |
| --- | --- |
| Local Docker POC first | **Linode from day one** — `terraform apply` |
| OpenHands + **LiteLLM** + Copilot model | **Agent Canvas** + **orchestrator** — **no LiteLLM** |
| Caddy / TLS / custom domain | **Bare IP** — `:8000` Canvas, `:8080` orchestrator |
| `.env` on laptop | **`terraform.tfvars` only** → cloud-init → `/etc/pmm-agentic-flow/env` |
| Copilot as model via proxy | **Cursor + Copilot CLIs via ACP** (subscription keys in tfvars) |
| BO Jira (NMS / BOVM) | **PMM** Jira project + `pmm` / `pmm-qa` repos |
| Recovery shell scripts | **Terraform bootstrap** — no manual recover scripts |

---

# The Loop at a Glance

<!-- _class: diagram -->

![w:1120](assets/loop.svg)

Two green gates = human decisions. Control plane stays warm; QA may spin an **ephemeral worker Linode** with FB images.

---

# Reference Architecture (as deployed)

<!-- _class: diagram -->

![h:470](assets/architecture.svg)

**Control plane** (g6-standard-4): Agent Canvas + orchestrator + Docker socket.
**QA workers** (g6-standard-8): ephemeral Linodes provisioned by orchestrator when entering In QA.

---

# Runtime Stack on Linode

<!-- _class: tight -->

| Piece | Role |
| --- | --- |
| **Terraform** | Linode + firewall + cloud-init; secrets in `terraform.tfvars` |
| **Agent Canvas** | UI `:8000`, conversations, in-container Docker sandboxes |
| **Orchestrator** | Jira webhook `:8080`, ticket store, worker lifecycle, Jira comments |
| **OpenSpec** | Spec-as-code in `percona/pmm` — commands unchanged |
| **Cursor / Copilot CLI** | Installed on Canvas start; **ACP** backends for chat |

> No Caddy, no LiteLLM, no local `docker compose` on the PC.

---

# Component 1 — OpenSpec (Context Layer)

- **Spec-as-code** — `openspec/changes/<id>/` in **`percona/pmm`**
- **Commands** — `/opsx:propose`, `/opsx:apply`, `/loop:qa`, `/loop:finalize`, `/opsx:archive`
- **Human gate** — spec PR reviewed before **In Progress**

> OpenSpec scope unchanged. Orchestrator maps Jira statuses → these commands.

---

# Component 2 — Orchestrator (custom)

- **Node service** on `:8080` — not a third-party SE agent product
- **Jira webhook** — `POST /hooks/jira` drives status transitions
- **Ticket store** — conversation id, phase, build iterations, worker id
- **Side effects** — Jira comments (PMM URL, SSH, conversation link), FB image resolution, **Linode worker** create/destroy
- **Simulate without Jira** — `scripts/simulate-transition.sh`

---

# Component 3 — Agent Canvas (agent runtime)

- **OpenHands Agent Canvas** — replaces legacy OpenHands Local GUI + LiteLLM stack
- **One ticket → one conversation** until Ready for Merge
- **Dev agent** — `/opsx:apply`, `make build` loop on control plane
- **QA agent** — `/loop:qa`, edits only `pmm-qa` paths
- **Sandbox** — Docker on the control plane; QA **PMM instance** on worker when needed

---

# LLM — How We Actually Run Models

<!-- _class: tight -->

| Path | Use |
| --- | --- |
| **ACP in Canvas** | `agent acp` / `copilot acp` — interactive dev & QA chat |
| **Keys in tfvars** | `cursor_api_key`, `github_copilot_token` → cloud-init |
| **Cloud Agents API** | Optional orchestrator path for headless repo work — not Canvas Settings → LLM |
| **Anthropic / OpenAI** | Optional native Canvas profiles if you add API keys |

> We **dropped LiteLLM**. Subscription CLIs + ACP match the POC constraint (no extra API spend).

---

# Why Not Copilot-as-Orchestrator?

<!-- class: invert tight -->

| | **Copilot coding agent (managed)** | **Our stack (self-hosted)** |
| --- | --- | --- |
| Jira + multi-phase workflow | Glue required | **Orchestrator** owns it |
| Warm env + SSH handover | Runner destroyed | **Conversation + worker** model |
| PMM-specific build/QA split | Generic | **Dev vs QA** agents + repo rules |
| Ops | Near-zero | We host Linode (~€20/mo POC) |
| Model | Copilot only | **ACP**: Cursor or Copilot CLI |

> Copilot/ACP is the **model slot inside Canvas**, not the workflow engine.

---

# Two Agents: Builder and Verifier

- **Dev** — `percona/pmm` (+ `grafana` when needed); OpenSpec apply + build loop
- **QA** — `percona/pmm-qa` only; Playwright via **playwright-cli** skill
- **Separation** — QA cannot edit app code; dev cannot edit test suites
- **Build loop** — `make build` retries until green (`MAX_BUILD_RETRIES`)

---

# Jira Lifecycle — PMM (not BO)

<!-- _class: diagram -->

![w:1160](assets/lifecycle.svg)

Statuses: Ready for Refinement → Ready for Work → **In Progress** → In Review → **In QA** → Ready for Merge.
Config: `config/jira-workflow.yaml`.

---

# Sandbox Lifecycle

<!-- _class: tight -->

| Phase | Where | What |
| --- | --- | --- |
| **In Progress** | Control plane | Dev sandbox; `make build`; links posted to Jira |
| **In Review** | Same sandbox | Links **refreshed** for engineer |
| **In QA** | **Worker Linode** | FB images from `pmm-submodules`; PMM URL for tests |
| **Ready for Merge** | Teardown | Worker destroyed; finalize + archive |

---

# QA in `pmm-qa`

- **Suites** — `e2e_tests/`, `cli/`, `qa-integration/` per ticket type
- **Playwright CLI** as agent skill (not MCP-by-default)
- **Evidence** — trace, video, report on PR
- **Xray** — still via **CI reporter** on the PR pipeline, not the agent

---

# Deployment — What We Actually Did

<!-- _class: tight -->

| | **POC (now)** | **Later** |
| --- | --- | --- |
| Provision | `terraform apply` | Same + hardened networking |
| Config | `terraform.tfvars` | Vault / team tokens |
| Control plane | Linode **g6-standard-4** | Resize if needed |
| QA workers | Ephemeral **g6-standard-8** | Pool / caps |
| Access | `http://<ip>:8000` | TLS + domain when ready |

> **No local Docker path** for the real stack — laptop only runs Terraform + browser.

---

# Security & Ops (POC)

- Secrets in **tfvars** / `/etc/pmm-agentic-flow/env` — never in git
- Linode firewall — SSH restricted (`admin_cidrs`), `:8000` / `:8080` open for POC
- Docker **IPv6 disabled** on bootstrap (registry pull reliability)
- Per-ticket caps — `SANDBOX_TTL_HOURS`, worker teardown on Ready for Merge

---

# Gaps (honest POC status)

<!-- _class: tight -->

| Done | Still to wire / prove |
| --- | --- |
| Linode + Canvas + orchestrator up | Real **Jira** project + webhook |
| Workflow engine code | End-to-end **one PMM ticket** |
| simulate-transition.sh | FB resolver on real submodule PRs |
| Cursor/Copilot CLI install | ACP backends configured in UI |
| Worker Linode client | In QA run with real Playwright |

---

# Phased Rollout (revised)

- **Phase 0 — Linode POC** *(now)* — stack up; Canvas + orchestrator smoke test
- **Phase 0b — First ticket** — Jira webhook + `PMM-xxxxx` through In Progress → In QA
- **Phase 1 — Hardening** — TLS, team tokens, review SLAs, KPIs
- **Phase 2 — QA depth** — worker + FB images automated; Xray in CI confirmed
- **Phase 3 — Scale** — concurrency, cost caps, more repos

---

<!-- class: invert lead -->
<!-- paginate: false -->
<!-- footer: '' -->

# Control plane is live.

## Next: Canvas + Jira + first PMM ticket

### Spine: Terraform → Agent Canvas + orchestrator → OpenSpec → Dev + QA → `pmm-qa` Playwright
