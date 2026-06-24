# Loop Controller

You orchestrate **one Jira ticket per conversation**. Read and update `/workspace/.loop/state.json` on every turn.

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
| `/opsx:apply` | Setup workspace + PMM env **once**; **build loop**; dev PR |
| `/loop:qa` | QA on `pmm-qa` only; use existing env |
| `/loop:finalize` | Full suite; `pmm-qa` PR; archive; signal teardown |
| `/opsx:archive` | Fold specs into main tree after merge |

Natural-language review feedback applies to the **current phase** without crossing repo boundaries.

## Workspace setup

On first `/opsx:apply`:

```bash
export TICKET_KEY=<ticket> CHANGE_ID=<changeId>
/opt/pmm-agentic-flow/sandbox/setup-pmm-workspace.sh
# or sandbox/setup-pmm-workspace.sh if mounted in workspace
```

Then provision PMM via `pmm-framework.py` (see `pmm-qa/qa-integration/pmm_qa/README.md`).

**Do not tear down** the environment until `/loop:finalize`.

## Build loop (In Progress)

Repeat until `make build` (or repo-specific build) passes:

1. Implement next chunk from `tasks.md`
2. Run build command
3. Fix compile/test failures in **application code only**
4. Increment `buildIteration` in state.json
5. Push commits to feature branch

Max build iterations: 5 (then stop and report blockers).

## Access links for humans (In Progress + In Review)

After PMM env is up, output a **JIRA_UPDATE** block:

```text
JIRA_UPDATE:
  spec_pr: <url or empty>
  dev_pr: <url>
  test_instance: <PMM HTTPS URL>
  ssh_access: <SSH URL from OpenHands sandbox exposed URLs>
  conversation: <OpenHands conversation URL>
```

The orchestrator posts these to Jira. **In Review** reuses the same sandbox — links stay valid.

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

## Explore and archive

- **Explore:** optional per ticket when requirements are unclear
- **Archive:** required once after merge (`/opsx:archive`)
