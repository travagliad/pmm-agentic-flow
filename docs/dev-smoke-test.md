# Dev smoke test (before In Review)

The dev agent **must** run functional smoke tests on the control plane **before** reporting dev complete or moving to In Review. Do not skip with excuses like "no PostgreSQL on control plane".

## What to provision

Read the ticket scope and OpenSpec — provision only what the change needs:

| Change touches | Provision (examples) |
|----------------|----------------------|
| PostgreSQL agent / RTA | `ps=17` or version from spec |
| MySQL / MariaDB | `ms=8.0`, `mdb=11.4`, etc. |
| MongoDB | `md=7.0` |
| UI only (no new DB agent) | PMM Server container or local managed smoke |

Always read `qa-integration/pmm_qa/scripts/database_options.py` and `pmm-framework.py --help` before choosing flags.

## Steps

```bash
PMM_QA_DIR=/projects/pmm-qa
FRAMEWORK="$PMM_QA_DIR/qa-integration/pmm-framework.py"

# 1. Pick databases for this ticket (example: PostgreSQL RTA)
python3 "$FRAMEWORK" --database ps=17   # adjust per scope

# 2. Smoke test the feature (examples — pick what applies)
#    - go test with integration tags if the package has them
#    - pmm-admin add/list agent against real DB
#    - curl managed API endpoints
#    - make -C ui build && spot-check UI if Grafana path changed

# 3. Teardown — mandatory, do not leave containers running
python3 "$FRAMEWORK" --destroy
```

Helper (reads ticket from env):

```bash
/opt/pmm-agentic-flow/src/sandbox/dev-smoke-test.sh --database ps=17
```

## Rules

- **Never** skip managed DB / integration smoke with "control plane has no DB".
- Docker is available on the control plane (`docker.io` from bootstrap).
- Document what you ran in the PR **Test plan** (databases, commands, result).
- Teardown after smoke passes or after a failed attempt — no orphaned `pmm-qa` network containers.
- Full Playwright E2E stays in **In QA**; dev smoke is narrower (prove the feature works once).
