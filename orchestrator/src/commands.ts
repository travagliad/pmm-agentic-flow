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

export function featureBranchForTicket(ticketKey: string, changeId: string): string {
  const slug = changeId.replace(new RegExp(`^${ticketKey}-`, "i"), "");
  return `agent/${ticketKey.toUpperCase()}-${slug}`;
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
    "3. Jira: use REST API — scripts/jira-issue.sh PMM-XXX or curl (see docs/jira-api.md). No Jira MCP.",
    `4. Branch ${branch}; commit spec files only.`,
    `5. Open DRAFT PR on percona/pmm titled exactly: ${prTitle}`,
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
    "Dev environment (local build on control plane — like a developer laptop):",
    "1. Work in /projects/pmm and /projects/pmm-qa.",
    "2. Run sandbox/setup-pmm-workspace.sh on the feature branch if needed.",
    "3. Do NOT run pmm-framework.py or start PMM Server FB — QA gets FB on In QA.",
    "4. Use gh CLI for PRs; Jira via REST API (scripts/jira-issue.sh, docs/jira-api.md).",
    "5. Optional: open Percona-Lab/pmm-submodules PR so Jenkins can publish FB images.",
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
    `- Push to ${branch}; open/update dev PR titled: ${prTitle}`,
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
