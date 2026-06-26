import type { StackConfig } from "./config.js";
import type { TicketRecord } from "./ticket-store.js";

export type IssueContext = {
  summary?: string;
  description?: string;
  acceptanceCriteria?: string;
};

export function slugFromSummary(summary: string): string {
  return summary
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "")
    .slice(0, 40);
}

export function changeIdForTicket(ticketKey: string, summary?: string): string {
  const slug = summary ? slugFromSummary(summary) : "change";
  return `${ticketKey.toUpperCase()}-${slug}`;
}

export function prTitleForTicket(ticketKey: string, summary?: string): string {
  const raw = summary?.trim() ?? "Change";
  const cleaned = raw
    .replace(/^\[[^\]]+\]\s*/i, "")
    .replace(/^openspec:\s*/i, "")
    .trim();
  return `${ticketKey.toUpperCase()}: ${cleaned || "Change"}`;
}

export function featureBranchForTicket(ticketKey: string, _changeId?: string): string {
  return ticketKey.toUpperCase();
}

/** One PR per ticket — propose opens draft; apply updates the same PR with code. */
export function existingPrHint(ticket: TicketRecord): string {
  const url = ticket.devPrUrl ?? ticket.specPrUrl;
  if (!url) return `No PR in ticket store yet — find it: gh pr list --repo percona/pmm --head ${ticket.ticketKey.toUpperCase()}`;
  return `Reuse this PR (do NOT open another): ${url}`;
}

/** Mandatory smoke test before In Review — provision real DBs, test, teardown. */
export function buildDevSmokeTestInstructions(): string {
  return [
    "Functional smoke test (mandatory BEFORE In Review / dev complete):",
    "1. Read docs/dev-smoke-test.md and qa-integration/pmm_qa/scripts/database_options.py.",
    "2. Provision DBs matching ticket scope (not only PostgreSQL — pick what the change needs).",
    "   Example: sandbox/dev-smoke-test.sh --database ps=17",
    "3. Run smoke: agent registration, API curl, UI build/spot-check — prove the feature works.",
    "4. sandbox/dev-smoke-test.sh --destroy (or pmm-framework.py --destroy) — always teardown.",
    "Forbidden: 'Managed DB tests — skip (no test instance on control plane)'. Docker is available.",
    "5. Record smoke steps + results in PR Test plan.",
    "",
  ].join("\n");
}
/** Mandatory last step of dev — opens Jenkins FB build for In QA. */
export function buildFbSubmodulesInstructions(ticket: TicketRecord, featureBranch: string): string {
  const submodulesRepo = "Percona-Lab/pmm-submodules";
  const prTitle = prTitleForTicket(ticket.ticketKey);
  return [
    "FB build (mandatory LAST step before reporting dev complete):",
    `1. percona/pmm PR must be ready (verify-pmm-change.sh passed, gh pr ready).`,
    `2. Clone or update ${submodulesRepo} (separate repo from pmm).`,
    `3. Point the pmm submodule at branch ${featureBranch} (ticket key only — no slashes).`,
    `4. Open a PR on ${submodulesRepo} — title MUST include ${ticket.ticketKey} (e.g. ${prTitle}).`,
    "5. Jenkins (JNKPercona) will comment Server docker / Client docker on that PR.",
    "   In QA cannot start without this PR — do not skip or defer to the human.",
    `6. Post the submodules PR URL in chat (and JIRA_UPDATE if you use it).`,
    "",
    "gh example:",
    `  gh pr create --repo ${submodulesRepo} --title "${prTitle}" --body "FB for ${ticket.ticketKey}; pmm branch ${featureBranch}"`,
  ].join("\n");
}

export function buildProposePrompt(
  ticket: TicketRecord,
  config: StackConfig,
  ctx: IssueContext,
): string {
  const changeId = ticket.changeId ?? changeIdForTicket(ticket.ticketKey, ctx.summary);
  const branch = featureBranchForTicket(ticket.ticketKey, changeId);
  const prTitle = prTitleForTicket(ticket.ticketKey, ctx.summary);
  return [
    "/opsx:propose " + ticket.ticketKey,
    "",
    "You are the Agent Controller. Follow agent-controller.md microagent.",
    "",
    `Ticket: ${ticket.ticketKey}`,
    `Change ID: ${changeId}`,
    `Feature branch: ${branch}`,
    `PR title: ${prTitle}`,
    `Dev repo: ${config.dev.repository}`,
    "",
    "Phase: SPEC_DRAFT",
    "",
    "Tasks:",
    "1. Run workspace setup if needed (see sandbox setup script in repo).",
    "2. Create openspec/changes/<changeId>/ with proposal.md, specs/, design.md, tasks.md.",
    "3. Jira: curl -u \"\\${JIRA_EMAIL}:\\${JIRA_API_TOKEN}\" \"\\${JIRA_BASE_URL}/rest/api/3/issue/<KEY>\" (see docs/jira-api.md).",
    `4. Branch ${branch}; commit spec files only.`,
    `5. Open ONE DRAFT PR on percona/pmm — title exactly: ${prTitle}`,
    "   PR body: lead with ## Summary (feature from Jira, not 'OpenSpec proposal for…').",
    "   Then ## OpenSpec (draft) with file paths. No 'Made with Cursor'.",
    "6. Output JIRA_UPDATE with spec_pr URL (apply phase will reuse the same PR).",
    "",
    ctx.summary ? `Summary: ${ctx.summary}` : "",
    ctx.description ? `Description:\n${ctx.description}` : "",
    ctx.acceptanceCriteria ? `Acceptance criteria:\n${ctx.acceptanceCriteria}` : "",
  ]
    .filter(Boolean)
    .join("\n");
}

export function buildApplyPrompt(
  ticket: TicketRecord,
  config: StackConfig,
  ctx: IssueContext,
): string {
  const changeId = ticket.changeId ?? changeIdForTicket(ticket.ticketKey, ctx.summary);
  const branch = featureBranchForTicket(ticket.ticketKey, changeId);
  const prTitle = prTitleForTicket(ticket.ticketKey, ctx.summary);
  return [
    "/opsx:apply",
    "",
    "You are the Agent Controller in DEV + BUILD mode. Follow dev-agent.md.",
    "",
    `Ticket: ${ticket.ticketKey}`,
    `Change ID: ${changeId}`,
    `Feature branch: ${branch}`,
    `PR title: ${prTitle}`,
    `Phase: IN_PROGRESS`,
    "",
    existingPrHint(ticket),
    "",
    "PR (same branch, same PR as spec — mandatory):",
    `1. Work on branch ${branch}; push implementation commits.`,
    `2. gh pr edit --repo percona/pmm <number> --title ${JSON.stringify(prTitle)}`,
    "3. Rewrite PR body: ## Summary (implementation), ## Changes (agent/ui/api paths),",
    "   ## OpenSpec (link to changes/<changeId>/), ## Test plan (unchecked CI items).",
    "   Remove 'OpenSpec proposal' / spec-only wording. Do not open a second PR.",
    "4. When lint/tests pass: gh pr ready --repo percona/pmm <number>",
    "",
    "Dev environment (control plane):",
    "1. Work in /projects/pmm and /projects/pmm-qa.",
    "2. Run sandbox/setup-pmm-workspace.sh on the feature branch if needed.",
    "3. gh CLI for PRs (always --repo percona/pmm); see docs/github-cli.md for token scopes.",
    "",
    buildDevSmokeTestInstructions(),
    buildFbSubmodulesInstructions(ticket, branch),
    "",
    "Build iterations (repeat until green or max retries):",
    `  implement tasks from openspec/changes/${changeId}/tasks.md`,
    "  if UI changed: make -C ui lint (eslint — same as CI)",
    "  if .proto changed: make -C api gen only — NEVER make gen at repo root",
    `  targeted go test for packages you touched`,
    `  before PR: sandbox/verify-pmm-change.sh /projects/pmm`,
    `  full build when possible: make env-up && make env TARGET=build (see docs/pmm-dev-workflow.md)`,
    "  increment buildIteration in /projects/.agent/state.json each cycle",
    "  do NOT open/update PR until verify-pmm-change.sh passes",
    "",
    "Rules:",
    "- Edit pmm (or grafana) application code ONLY.",
    "- Do NOT write pmm-qa tests yet.",
    `- Push to ${branch}; update the existing PR (see above) — title: ${prTitle}`,
    "- Output JIRA_UPDATE with dev_pr (same URL as spec_pr if one PR).",
    "- Only after smoke test + FB submodules PR: report dev phase complete.",
    "",
    ticket.fbServerImage
      ? `FB images already published (for later QA): ${ticket.fbServerImage}`
      : "FB images: open pmm-submodules PR (see FB build steps above) before finishing dev.",
    "",
    ctx.acceptanceCriteria ? `Acceptance criteria:\n${ctx.acceptanceCriteria}` : "",
  ]
    .filter(Boolean)
    .join("\n");
}

export function buildQaPrompt(ticket: TicketRecord, config: StackConfig, ctx: IssueContext): string {
  return [
    "/agent:qa",
    "",
    "You are the Agent Controller in QA mode. Follow qa-agent.md.",
    "",
    `Ticket: ${ticket.ticketKey}`,
    `Change ID: ${ticket.changeId}`,
    `Phase: IN_QA`,
    "",
    ticket.fbServerImage ? `FB server image: ${ticket.fbServerImage}` : "FB server image pending — check Jira.",
    ticket.fbClientImage ? `FB client image: ${ticket.fbClientImage}` : "",
    "",
    "Use FB images from pmm-submodules for PMM testing context.",
    "Clone/update pmm-qa in /projects/pmm-qa for test edits.",
    "",
    `Editable paths: ${config.qa.editable_paths.join(", ")}`,
    `Suite: ${config.qa.default_suite}`,
    `Runner: ${config.qa.suites[config.qa.default_suite]?.runner ?? "see pmm-qa AGENTS.md"}`,
    "",
    "Tasks:",
    "1. Map OpenSpec scenarios to Playwright tests in pmm-qa.",
    "2. Run tests; collect trace/video/HTML report.",
    "3. If tests expose dev bugs: report in chat — do NOT patch pmm code.",
    "4. Output JIRA_UPDATE with artifact paths.",
    "",
    ctx.acceptanceCriteria ? `Acceptance criteria:\n${ctx.acceptanceCriteria}` : "",
  ]
    .filter(Boolean)
    .join("\n");
}

export function buildFinalizePrompt(ticket: TicketRecord, config: StackConfig): string {
  return [
    "/agent:finalize",
    "",
    "Phase: READY_FOR_MERGE",
    "",
    `Ticket: ${ticket.ticketKey}`,
    "",
    "Tasks:",
    "1. Run full applicable Playwright suite.",
    "2. Max 2 retries per flaky test; fail loudly otherwise.",
    "3. Open PR on percona/pmm-qa if tests were written.",
    "4. Run /opsx:archive for the change in pmm.",
    "5. Chat runner Linode will be destroyed by the orchestrator.",
    "6. Output JIRA_UPDATE with qa_pr if applicable.",
    "",
    `QA suite: ${config.qa.default_suite}`,
  ].join("\n");
}

export function buildInReviewNotice(ticket: TicketRecord): string {
  const branch = ticket.changeId
    ? featureBranchForTicket(ticket.ticketKey, ticket.changeId)
    : ticket.ticketKey.toUpperCase();
  return [
    "Ticket moved to In Review.",
    "",
    "Dev build was local (make build) — no QA PMM instance is running yet.",
    "Review the dev PR and pmm-submodules FB PR.",
    "",
    ticket.devPrUrl ? `Dev PR: ${ticket.devPrUrl}` : "",
    ticket.fbServerImage
      ? `FB ready for QA: ${ticket.fbServerImage}`
      : `FB build: dev agent must open ${branch} on Percona-Lab/pmm-submodules (JNKPercona comment).`,
    "",
    "When FB images are published, move to In QA — runner + QA agent start automatically.",
    "To request agent changes, reply in this conversation or comment on the PR.",
  ]
    .filter(Boolean)
    .join("\n");
}

export function buildArchivePrompt(ticket: TicketRecord): string {
  return [
    "/opsx:archive",
    "",
    `Ticket: ${ticket.ticketKey}`,
    `Change ID: ${ticket.changeId}`,
    "Merge delta specs into main openspec tree and move change to archive/.",
  ].join("\n");
}
