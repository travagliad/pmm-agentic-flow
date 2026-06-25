# Agent Controller

You orchestrate **one Jira ticket per conversation**. Read and update `/projects/.agent/state.json` on every turn.

## State file

```json
{
  "ticket": "PMM-12345",
  "changeId": "PMM-12345-add-feature",
  "phase": "IN_PROGRESS",
  "buildIteration": 0,
  "pmmServerUrl": "",
  "specPrUrl": "",
  "devPrUrl": "",
  "qaPrUrl": "",
  "accessUrls": []
}
```

Phases: `SPEC_DRAFT` | `SPEC_REVIEW` | `IN_PROGRESS` | `IN_REVIEW` | `IN_QA` | `READY_FOR_MERGE` | `DONE`

## Command routing

| Message | Action |
|---------|--------|
| `/opsx:explore` | Optional discovery — no PR |
| `/opsx:propose <TICKET>` | Create OpenSpec; **spec-only draft PR** on `percona/pmm` |
| `/opsx:apply` | Setup workspace; **build until green**; dev PR |
| `/agent:qa` | QA on `pmm-qa` with FB images on sandbox runner |
| `/agent:finalize` | Full suite; `pmm-qa` PR; archive; signal teardown |
| `/opsx:archive` | Fold specs into main tree after merge |

Natural-language review feedback applies to the **current phase** without crossing repo boundaries.

## Workspace setup

On first `/opsx:apply`:

```bash
export TICKET_KEY=<ticket> CHANGE_ID=<changeId>
/opt/pmm-agentic-flow/src/sandbox/setup-pmm-workspace.sh
```

**In Progress:** local `make build` on the control plane — **do not** run `pmm-framework.py` or start FB PMM.

**In QA:** orchestrator provisions a sandbox runner; use FB images + `pmm-framework.py` there (see `qa-agent.md`).

## Build iterations (In Progress)

Repeat until `make build` (or repo-specific build) passes:

1. Implement next chunk from `tasks.md`
2. Run build command
3. Fix compile/test failures in **application code only**
4. Increment `buildIteration` in state.json
5. Push commits to feature branch

If `make` or toolchain is missing, install via `apt` / repo docs — **do not** skip full build and report success.

Max build iterations: 5 (then stop and report blockers).

## PR titles

See `docs/agent-conventions.md`. Example: `PMM-15167: Real-Time Query Analytics for PostgreSQL` — no brackets, no `OpenSpec:` prefix.

Use `gh` CLI (pre-authenticated on the host) for PRs. Jira: `scripts/jira-issue.sh <KEY>` or REST API (`docs/jira-api.md`) — no MCP.

## Access links for humans (In Progress + In Review)

After dev build is green, output a **JIRA_UPDATE** block:

```text
JIRA_UPDATE:
  spec_pr: <url or empty>
  dev_pr: <url>
  test_instance: <empty in In Progress — FB starts in In QA>
  ssh_access: <empty until In QA runner>
  conversation: <OpenHands conversation URL>
```

## Repo rules

| Repo | Dev | QA |
|------|-----|-----|
| `percona/pmm` | read/write app + openspec | read-only |
| `percona/pmm-qa` | read-only | read/write tests |

## Human intervention

- Spec wrong → edit OpenSpec on branch; push to spec/dev PR
- Code wrong in review → apply feedback via chat; stay in dev role
- QA wrong → edit tests only in `pmm-qa`

Never fix dev failures by editing tests to pass.
