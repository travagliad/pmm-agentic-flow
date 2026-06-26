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
| `/opsx:propose <TICKET>` | OpenSpec files + **one draft PR** (spec review) |
| `/opsx:apply` | Implementation on **same branch/PR** — rewrite PR body, push code |
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

**In Progress:** local build + **functional smoke** via `pmm-framework.py` on the control plane (provision DBs → test → teardown). See `docs/dev-smoke-test.md`.

**In QA:** orchestrator provisions a sandbox runner; use FB images + full Playwright (see `qa-agent.md`).

## Build iterations (In Progress)

Repeat until `make build` (or repo-specific build) passes:

1. Implement next chunk from `tasks.md`
2. Run build command
3. Fix compile/test failures in **application code only**
4. Increment `buildIteration` in state.json
5. Push commits to feature branch

If `make` or toolchain is missing, install via `apt` / repo docs — **do not** skip full build and report success.

Max build iterations: 5 (then stop and report blockers).

## PR lifecycle (one PR per ticket)

1. **Propose:** draft PR titled `PMM-XXXX: <Jira summary>`. Body leads with feature summary, not "OpenSpec proposal for…".
2. **Apply:** same branch, **same PR** — `gh pr edit` new title/body, push code, `gh pr ready` when done.
3. Never open a second PR for the same ticket. Store URL in `specPrUrl` / `devPrUrl` in state.json.

## Dev complete — FB submodules PR (last step)

After smoke test passes on percona/pmm, **before** reporting done:

1. Open PR on `Percona-Lab/pmm-submodules` with pmm submodule on branch `PMM-XXXX` (ticket key).
2. Title must include ticket key — Jenkins publishes FB docker images (JNKPercona comment).
3. Post submodules PR URL in chat.

In QA depends on this PR. See `dev-agent.md`.

## PR titles

See `docs/agent-conventions.md`. Example: `PMM-15167: Real-Time Query Analytics for PostgreSQL` — no brackets, no `OpenSpec:` prefix.

Use `gh` for PRs — always pass `--repo percona/pmm` (see `docs/github-cli.md`). Jira via curl (`docs/jira-api.md`).

## Access links for humans (In Progress + In Review)

After dev build is green, output a **JIRA_UPDATE** block:

```text
JIRA_UPDATE:
  spec_pr: <url or empty>
  dev_pr: <url>
  test_instance: <smoke test summary — pmm-framework DBs used>
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
