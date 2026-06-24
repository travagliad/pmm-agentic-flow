import type { Env, JiraWorkflowConfig, LoopConfig } from "./config.js";
import { JiraClient } from "./jira-client.js";
import {
  buildApplyPrompt,
  buildArchivePrompt,
  buildFinalizePrompt,
  buildInReviewNotice,
  buildProposePrompt,
  buildQaPrompt,
  changeIdForTicket,
  type IssueContext,
} from "./commands.js";
import { OpenHandsClient, type ExposedUrl } from "./openhands-client.js";
import { TicketStore, type TicketPhase, type TicketRecord } from "./ticket-store.js";

export type TransitionInput = {
  ticketKey: string;
  statusName: string;
  issue?: IssueContext;
};

export class WorkflowEngine {
  private readonly store: TicketStore;
  private readonly openhands: OpenHandsClient;
  private readonly jira: JiraClient;

  constructor(
    private readonly env: Env,
    private readonly loop: LoopConfig,
    private readonly workflow: JiraWorkflowConfig,
  ) {
    this.store = new TicketStore(`${env.dataDir}/tickets`);
    this.openhands = new OpenHandsClient(env);
    this.jira = new JiraClient(env);
  }

  listTickets(): TicketRecord[] {
    return this.store.list();
  }

  getTicket(ticketKey: string): TicketRecord | undefined {
    return this.store.get(ticketKey);
  }

  resolvePhase(statusName: string): TicketPhase | undefined {
    const s = this.workflow.jira.statuses;
    const normalized = statusName.trim().toLowerCase();
    const entries: Array<[TicketPhase, string]> = [
      ["ready_for_refinement", s.ready_for_refinement],
      ["ready_for_work", s.ready_for_work],
      ["in_progress", s.in_progress],
      ["in_review", s.in_review],
      ["in_qa", s.in_qa],
      ["ready_for_merge", s.ready_for_merge],
    ];
    for (const [phase, label] of entries) {
      if (label.toLowerCase() === normalized) return phase;
    }
    return undefined;
  }

  async handleTransition(input: TransitionInput): Promise<TicketRecord> {
    const phase = this.resolvePhase(input.statusName);
    if (!phase) {
      throw new Error(`Unknown Jira status: ${input.statusName}`);
    }

    const ticket = this.store.getOrCreate(input.ticketKey, phase);
    ticket.phase = phase;
    if (!ticket.changeId && input.issue?.summary) {
      ticket.changeId = changeIdForTicket(input.ticketKey, input.issue.summary);
    }
    this.store.save(ticket);

    switch (phase) {
      case "ready_for_refinement":
        await this.dispatchCommand(ticket, buildProposePrompt(ticket, this.loop, input.issue ?? {}));
        break;
      case "ready_for_work":
        this.store.log(ticket, "Human gate: PO reviews spec PR.");
        break;
      case "in_progress":
        await this.dispatchCommand(ticket, buildApplyPrompt(ticket, this.loop, input.issue ?? {}));
        await this.refreshAccessLinks(ticket, "in_progress");
        break;
      case "in_review":
        await this.handleInReview(ticket);
        break;
      case "in_qa":
        await this.dispatchCommand(ticket, buildQaPrompt(ticket, this.loop, input.issue ?? {}));
        await this.refreshAccessLinks(ticket, "in_qa");
        break;
      case "ready_for_merge":
        await this.dispatchCommand(ticket, buildFinalizePrompt(ticket, this.loop));
        await this.dispatchCommand(ticket, buildArchivePrompt(ticket));
        ticket.phase = "done";
        this.store.save(ticket);
        break;
    }

    return ticket;
  }

  async dispatchCommand(ticket: TicketRecord, message: string): Promise<void> {
    if (!ticket.conversationId) {
      const start = await this.openhands.startConversation({
        message,
        repository: this.loop.dev.repository,
        branch: this.loop.dev.default_branch,
      });
      ticket.conversationId = await this.openhands.waitForConversation(start.id);
      this.store.log(ticket, `Started conversation ${ticket.conversationId}`);
    } else {
      await this.openhands.sendMessage(ticket.conversationId, message);
      this.store.log(ticket, `Sent message to conversation ${ticket.conversationId}`);
    }
    this.store.save(ticket);
    await this.postConversationLink(ticket);
  }

  async handleInReview(ticket: TicketRecord): Promise<void> {
    if (this.workflow.access_links.refresh_on_in_review) {
      await this.refreshAccessLinks(ticket, "in_review");
    }
    if (ticket.conversationId) {
      await this.openhands.sendMessage(ticket.conversationId, buildInReviewNotice(ticket));
      this.store.log(ticket, "Posted In Review notice to conversation.");
    }
  }

  async refreshAccessLinks(ticket: TicketRecord, reason: string): Promise<void> {
    if (!ticket.conversationId) return;

    // Allow sandbox time to expose URLs after env setup
    await sleep(reason === "in_progress" ? 15_000 : 3000);

    const urls = await this.openhands.getAccessUrls(ticket.conversationId);
    ticket.accessUrls = urls;

    const pmm = urls.find((u) => /pmm|8443|443|preview|server/i.test(u.name + u.url));
    if (pmm) ticket.pmmServerUrl = pmm.url;

    this.store.log(ticket, `Refreshed access links (${reason}): ${urls.length} URLs`);
    this.store.save(ticket);
    await this.postAccessBundle(ticket, reason);
  }

  private async postConversationLink(ticket: TicketRecord): Promise<void> {
    if (!ticket.conversationId) return;
    const url = this.openhands.conversationPublicUrl(ticket.conversationId);
    const tpl = this.workflow.jira.comments.conversation;
    await this.jira.addComment(ticket.ticketKey, tpl.replace("{url}", url));
  }

  private async postAccessBundle(ticket: TicketRecord, reason: string): Promise<void> {
    const { comments } = this.workflow.jira;
    const lines: string[] = [`*Sandbox access* (${reason})`, ""];

    if (ticket.conversationId) {
      lines.push(comments.conversation.replace("{url}", this.openhands.conversationPublicUrl(ticket.conversationId)));
    }
    if (ticket.pmmServerUrl) {
      lines.push(comments.test_instance.replace("{url}", ticket.pmmServerUrl));
    }
    if (ticket.devPrUrl) {
      lines.push(comments.dev_pr.replace("{url}", ticket.devPrUrl));
    }

    for (const u of ticket.accessUrls) {
      if (/ssh/i.test(u.name)) {
        lines.push(comments.ssh_access.replace("{url}", u.url).replace("{host}", u.url));
      }
      if (/vscode|code|editor/i.test(u.name)) {
        lines.push(`VS Code: ${u.url}`);
      }
    }

    if (this.workflow.access_links.include_ssh && !ticket.accessUrls.some((u) => /ssh/i.test(u.name))) {
      lines.push(
        comments.ssh_access.replace("{url}", "(see OpenHands sandbox SSH in conversation UI)").replace("{host}", "sandbox"),
      );
    }

    const body = comments.access_bundle
      ? comments.access_bundle
          .replace("{reason}", reason)
          .replace("{links}", lines.join("\n"))
      : lines.join("\n");

    await this.jira.addComment(ticket.ticketKey, body);
  }

  async updateTicketLinks(
    ticketKey: string,
    links: { specPrUrl?: string; devPrUrl?: string; qaPrUrl?: string },
  ): Promise<TicketRecord> {
    const ticket = this.store.getOrCreate(ticketKey);
    if (links.specPrUrl) ticket.specPrUrl = links.specPrUrl;
    if (links.devPrUrl) ticket.devPrUrl = links.devPrUrl;
    if (links.qaPrUrl) ticket.qaPrUrl = links.qaPrUrl;
    this.store.save(ticket);

    if (links.specPrUrl) {
      await this.jira.addComment(ticketKey, this.workflow.jira.comments.spec_pr.replace("{url}", links.specPrUrl));
    }
    if (links.devPrUrl) {
      await this.jira.addComment(ticketKey, this.workflow.jira.comments.dev_pr.replace("{url}", links.devPrUrl));
    }
    return ticket;
  }
}

function sleep(ms: number) {
  return new Promise((r) => setTimeout(r, ms));
}
