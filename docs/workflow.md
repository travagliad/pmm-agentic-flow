# Workflow — Jira statuses, OpenSpec commands, and agents

**One ticket = one OpenHands conversation = one persistent sandbox** until Ready for Merge.

Access links (PMM URL, VS Code, **SSH**) are posted when entering **In Progress** and **refreshed on In Review** so engineers can verify live before QA.

---

## Jira status → command → outcome

| Jira status | Trigger | Who | Outcome |
|-------------|---------|-----|---------|
| **Ready for Refinement** | `/opsx:propose <TICKET>` | Automation or chat | OpenSpec + **draft spec PR on `pmm`** |
| **Ready for Work** | *(none)* | PO reviews spec PR | → **In Progress** |
| **In Progress** | `/opsx:apply` | Automation | Env setup + **build loop** + dev PR; **access links → Jira** |
| **In Review** | *(none)* | Engineer reviews PR | **Same sandbox links refreshed in Jira**; → In QA |
| **In QA** | `/loop:qa` | Automation | Playwright in `pmm-qa`; instance link in Jira |
| **Ready for Merge** | `/loop:finalize` | Automation | Teardown; merge; optional **`pmm-qa` PR**; archive |

---

## Build loop (In Progress)

Dev does not run once — it loops until the build is green:

```text
implement task chunk → make build → fix → rebuild → push
```

`buildIteration` is tracked in `/workspace/.loop/state.json`. Max retries: `MAX_BUILD_RETRIES` (default 5).

PMM env (`pmm-framework.py` / FB Docker) is provisioned **when entering In QA**, not during dev. Dev uses local `make build` on the control plane.

```text
In Progress → local make build (no PMM FB)
In QA       → orchestrator creates QA worker Linode with Jenkins FB images
Ready for Merge → worker destroyed
```

See [sandbox-lifecycle.md](./sandbox-lifecycle.md).

---

## Access links timeline

| Stage | PMM URL | SSH | VS Code / conversation |
|-------|---------|-----|------------------------|
| In Progress | Posted after env up | Posted from sandbox `exposed_urls` | Posted |
| In Review | **Refreshed** (same sandbox) | **Refreshed** | Refreshed |
| In QA | Still valid | Still valid | Still valid |
| Ready for Merge | Teardown | Gone | Conversation archived |

Orchestrator: `POST /api/tickets/:key/refresh-access` to force refresh.

---

## OpenSpec commands

```text
/opsx:explore     optional
/opsx:propose     Ready for Refinement
/opsx:apply       In Progress (env + build loop + dev)
/loop:qa          In QA
/loop:finalize    Ready for Merge
/opsx:archive     after merge
```

---

## POC without Jira

```bash
export ORCHESTRATOR_API_KEY=...
export LOOP_BASE_URL=https://loop.example.com

./scripts/simulate-transition.sh PMM-14915 "Ready for Refinement" "Add feature X"
# PO approves spec PR on GitHub
./scripts/simulate-transition.sh PMM-14915 "In Progress"
# engineer reviews — links already in Jira
./scripts/simulate-transition.sh PMM-14915 "In Review"
./scripts/simulate-transition.sh PMM-14915 "In QA"
./scripts/simulate-transition.sh PMM-14915 "Ready for Merge"
```

Or type the same commands in the OpenHands chat.

---

## Jira webhook

```text
POST https://loop.example.com/hooks/jira
Header: x-webhook-secret: <JIRA_WEBHOOK_SECRET>
Body: Jira automation payload (issue key + status)
```

Configure in `config/jira-workflow.yaml` — map your exact status names.

---

## Collaboration

Share the **conversation URL** from Jira. Intervention via chat or PR comments — agent applies feedback in the same sandbox without manual code as the default path.

See [pmm-architecture.md](./pmm-architecture.md) for repo layout.
