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

export function buildProposePrompt(
  ticket: TicketRecord,
  config: StackConfig,
  ctx: IssueContext,
): string {
  const changeId = ticket.changeId ?? changeIdForTicket(ticket.ticketKey, ctx.summary);
  return [
    "/opsx:propose " + ticket.ticketKey,
    "",
    "You are the Loop Controller. Follow loop-controller.md microagent.",
    "",
    `Ticket: ${ticket.ticketKey}`,
    `Change ID: ${changeId}`,
    `Dev repo: ${config.dev.repository}`,
    "",
    "Phase: SPEC_DRAFT",
    "",
    "Tasks:",
    "1. Run workspace setup if needed (see sandbox setup script in repo).",
    "2. Create openspec/changes/<changeId>/ with proposal.md, specs/, design.md, tasks.md.",
    "3. Use Jira context below for requirements.",
    "4. Branch loop/<ticket>-<slug>; commit spec files only.",
    "5. Open DRAFT PR on percona/pmm (spec only).",
    "6. Output JIRA_UPDATE block with spec_pr URL.",
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
  return [
    "/opsx:apply",
    "",
    "You are the Loop Controller in DEV + BUILD mode. Follow dev-agent.md.",
    "",
    `Ticket: ${ticket.ticketKey}`,
    `Change ID: ${changeId}`,
    `Phase: IN_PROGRESS`,
    "",
    "Dev environment (local build — like a developer laptop):",
    "1. Clone /workspace/pmm and /workspace/pmm-qa if missing.",
    "2. Run sandbox/setup-pmm-workspace.sh on the feature branch.",
    "3. Do NOT run pmm-framework.py or start PMM Server FB — QA gets FB on In QA.",
    "4. Optional: ensure pmm-submodules PR exists so Jenkins can publish FB images.",
    "",
    "Build loop (repeat until green or max retries):",
    `  implement tasks from openspec/changes/${changeId}/tasks.md`,
    `  run: ${config.dev.build_command}`,
    "  if build fails → fix code → rebuild",
    "  increment buildIteration in state.json each cycle",
    "",
    "Rules:",
    "- Edit pmm (or grafana) application code ONLY.",
    "- Do NOT write pmm-qa tests yet.",
    "- Push to feature branch; open/update dev PR and pmm-submodules PR when ready.",
    "- Output JIRA_UPDATE with dev_pr (and submodules PR if opened).",
    "",
    ticket.fbServerImage
      ? `FB images already published (for later QA): ${ticket.fbServerImage}`
      : "FB images: not ready yet — QA environment starts when ticket moves to In QA.",
    "",
    ctx.acceptanceCriteria ? `Acceptance criteria:\n${ctx.acceptanceCriteria}` : "",
  ]
    .filter(Boolean)
    .join("\n");
}

export function buildQaPrompt(ticket: TicketRecord, config: StackConfig, ctx: IssueContext): string {
  return [
    "/loop:qa",
    "",
    "You are the Loop Controller in QA mode. Follow qa-agent.md.",
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
    "3. Dev/QA loop if tests expose dev bugs: report in chat — do NOT patch pmm code.",
    "4. Output JIRA_UPDATE with artifact paths.",
    "",
    ctx.acceptanceCriteria ? `Acceptance criteria:\n${ctx.acceptanceCriteria}` : "",
  ]
    .filter(Boolean)
    .join("\n");
}

export function buildFinalizePrompt(ticket: TicketRecord, config: StackConfig): string {
  return [
    "/loop:finalize",
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
  return [
    "Ticket moved to In Review.",
    "",
    "Dev build was local (make build) — no QA PMM instance is running yet.",
    "Review the dev PR and dev/submodules PRs.",
    "",
    ticket.devPrUrl ? `Dev PR: ${ticket.devPrUrl}` : "",
    ticket.fbServerImage ? `FB ready for QA: ${ticket.fbServerImage}` : "FB build: ensure pmm-submodules PR has JNKPercona comment.",
    "",
    "When ready for QA testing, move the ticket to In QA — the FB environment will start automatically.",
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
