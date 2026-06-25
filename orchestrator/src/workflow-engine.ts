import type { Env, JiraWorkflowConfig, StackConfig } from "./config.js";
import { chatsPerWorker } from "./config.js";
import {
  buildApplyPrompt,
  buildArchivePrompt,
  buildFinalizePrompt,
  buildInReviewNotice,
  buildProposePrompt,
  buildQaEnvironmentStartingNotice,
  buildQaPrompt,
  changeIdForTicket,
  type IssueContext,
} from "./commands.js";
import { FbResolver } from "./fb-resolver.js";
import { JiraClient } from "./jira-client.js";
import { LinodeWorkerClient } from "./linode-worker.js";
import { OpenHandsClient } from "./openhands-client.js";
import { TicketStore, type TicketPhase, type TicketRecord } from "./ticket-store.js";
import { WorkerStore } from "./worker-store.js";

export type TransitionInput = {
  ticketKey: string;
  statusName: string;
  issue?: IssueContext;
};

export class WorkflowEngine {
  private readonly store: TicketStore;
  private readonly workerStore: WorkerStore;
  private readonly openhands: OpenHandsClient;
  private readonly jira: JiraClient;
  private readonly fb: FbResolver;
  private readonly worker: LinodeWorkerClient;
  private readonly maxChatsPerWorker: number;

  constructor(
    private readonly env: Env,
    private readonly stack: StackConfig,
    private readonly workflow: JiraWorkflowConfig,
  ) {
    this.store = new TicketStore(`${env.dataDir}/tickets`);
    this.workerStore = new WorkerStore(`${env.dataDir}/workers`);
    this.openhands = new OpenHandsClient(env);
    this.jira = new JiraClient(env);
    this.fb = new FbResolver(env);
    this.worker = new LinodeWorkerClient(env, stack);
    this.maxChatsPerWorker = chatsPerWorker(stack);
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
        await this.dispatchCommand(ticket, buildProposePrompt(ticket, this.stack, input.issue ?? {}));
        break;
      case "ready_for_work":
        this.store.log(ticket, "Human gate: PO reviews spec PR.");
        break;
      case "in_progress":
        await this.syncFbArtifacts(ticket, false);
        await this.dispatchCommand(ticket, buildApplyPrompt(ticket, this.stack, input.issue ?? {}));
        await this.postConversationLink(ticket);
        break;
      case "in_review":
        await this.syncFbArtifacts(ticket, false);
        await this.handleInReview(ticket);
        break;
      case "in_qa":
        await this.handleInQa(ticket, input.issue ?? {});
        break;
      case "ready_for_merge":
        await this.teardownWorker(ticket);
        await this.dispatchCommand(ticket, buildFinalizePrompt(ticket, this.stack));
        await this.dispatchCommand(ticket, buildArchivePrompt(ticket));
        ticket.phase = "done";
        this.store.save(ticket);
        break;
    }

    return ticket;
  }

  async syncFbArtifacts(ticket: TicketRecord, required: boolean): Promise<void> {
    try {
      const fb = await this.fb.resolveForTicket(ticket.ticketKey);
      if (!fb) {
        if (required) {
          throw new Error(
            `No FB images found for ${ticket.ticketKey}. Open pmm-submodules PR and wait for JNKPercona comment.`,
          );
        }
        this.store.log(ticket, "FB artifacts not found yet.");
        return;
      }
      ticket.submodulesPr = fb.submodulesPr;
      ticket.fbServerImage = fb.serverImage;
      ticket.fbClientImage = fb.clientImage;
      this.store.save(ticket);
      this.store.log(
        ticket,
        `FB resolved from PR #${fb.submodulesPr}: ${fb.serverImage}`,
      );
      if (required) {
        await this.jira.addComment(
          ticket.ticketKey,
          `FB build (pmm-submodules#${fb.submodulesPr}):\nServer: ${fb.serverImage}\nClient: ${fb.clientImage}`,
        );
      }
    } catch (err) {
      if (required) throw err;
      this.store.log(ticket, `FB sync skipped: ${err instanceof Error ? err.message : String(err)}`);
    }
  }

  async handleInQa(ticket: TicketRecord, ctx: IssueContext): Promise<void> {
    await this.jira.addComment(
      ticket.ticketKey,
      `QA environment: assigning worker (up to ${this.maxChatsPerWorker} chats per VM). Each chat runs in its own Docker sandbox.`,
    );

    if (ticket.conversationId) {
      await this.openhands.sendMessage(ticket.conversationId, buildQaEnvironmentStartingNotice(ticket));
    }

    await this.syncFbArtifacts(ticket, true);

    if (!ticket.fbServerImage || !ticket.fbClientImage) {
      throw new Error("FB images required before QA provisioning");
    }

    if (!this.worker.enabled) {
      await this.jira.addComment(
        ticket.ticketKey,
        "LINODE_TOKEN not configured — cannot auto-provision QA worker. Set LINODE_TOKEN on control plane and re-transition to In QA.",
      );
      await this.dispatchCommand(ticket, buildQaPrompt(ticket, this.stack, ctx));
      return;
    }

    if (!this.env.workerRootPassword) {
      throw new Error("WORKER_ROOT_PASSWORD required to create QA worker Linodes");
    }

    const assigned = await this.acquireWorker(ticket);
    ticket.workerLinodeId = assigned.linodeId;
    ticket.workerIp = assigned.ip;
    ticket.workerHostname = assigned.hostname;
    ticket.pmmServerUrl = assigned.pmmUrl;
    this.store.save(ticket);

    const pool = this.workerStore.get(assigned.linodeId);
    const slot = pool?.ticketKeys.length ?? 1;
    await this.jira.addComment(
      ticket.ticketKey,
      `QA worker ${assigned.ip} (Linode ${assigned.linodeId}, chat ${slot}/${this.maxChatsPerWorker}). Waiting for PMM and Canvas…`,
    );

    const [pmmReady, canvasReady] = await Promise.all([
      this.worker.waitUntilPmmReady(assigned.ip),
      this.worker.waitUntilCanvasReady(assigned.ip),
    ]);

    if (!pmmReady) {
      await this.jira.addComment(
        ticket.ticketKey,
        `QA worker ${assigned.ip}: PMM did not respond on :8443 within timeout.`,
      );
    }
    if (!canvasReady) {
      await this.jira.addComment(
        ticket.ticketKey,
        `QA worker ${assigned.ip}: Agent Canvas did not respond on :8000 within timeout.`,
      );
    }

    await this.jira.addComment(
      ticket.ticketKey,
      this.workflow.jira.comments.test_instance.replace("{url}", ticket.pmmServerUrl ?? assigned.pmmUrl),
    );

    const qaCanvas = new OpenHandsClient(this.env, {
      baseUrl: assigned.canvasBaseUrl,
      publicUrl: assigned.canvasPublicUrl,
    });
    await this.dispatchCommand(ticket, buildQaPrompt(ticket, this.stack, ctx), qaCanvas, "qaConversationId");
    await this.postAccessBundle(ticket, "in_qa");
  }

  private async acquireWorker(ticket: TicketRecord) {
    const existing = this.workerStore.findWithCapacity(this.maxChatsPerWorker);
    if (existing) {
      this.workerStore.assignTicket(existing.linodeId, ticket.ticketKey, this.maxChatsPerWorker);
      return {
        linodeId: existing.linodeId,
        ip: existing.ip,
        hostname: existing.ip,
        pmmUrl: existing.pmmUrl,
        canvasBaseUrl: existing.canvasBaseUrl,
        canvasPublicUrl: existing.canvasPublicUrl,
      };
    }

    const worker = await this.worker.provisionQaWorker(ticket.ticketKey, {
      submodulesPr: ticket.submodulesPr!,
      serverImage: ticket.fbServerImage!,
      clientImage: ticket.fbClientImage!,
    });
    this.workerStore.save(this.worker.toPoolRecord(worker, [ticket.ticketKey]));
    return worker;
  }

  async teardownWorker(ticket: TicketRecord): Promise<void> {
    if (!ticket.workerLinodeId) return;
    const linodeId = ticket.workerLinodeId;
    const released = this.workerStore.releaseTicket(linodeId, ticket.ticketKey);
    ticket.workerLinodeId = undefined;
    ticket.workerIp = undefined;
    ticket.workerHostname = undefined;
    ticket.qaConversationId = undefined;
    this.store.save(ticket);

    if (!released || released.ticketKeys.length > 0) {
      this.store.log(ticket, `Released QA slot on worker ${linodeId} (${released?.ticketKeys.length ?? 0} chats remain)`);
      return;
    }

    try {
      await this.worker.destroy(linodeId);
      this.workerStore.remove(linodeId);
      this.store.log(ticket, `Destroyed empty worker Linode ${linodeId}`);
      await this.jira.addComment(ticket.ticketKey, `QA worker destroyed (Linode ${linodeId}) — no active chats.`);
    } catch (err) {
      this.store.log(ticket, `Worker destroy failed: ${err instanceof Error ? err.message : String(err)}`);
    }
  }

  async dispatchCommand(
    ticket: TicketRecord,
    message: string,
    client: OpenHandsClient = this.openhands,
    conversationField: "conversationId" | "qaConversationId" = "conversationId",
  ): Promise<void> {
    const repo =
      conversationField === "qaConversationId"
        ? this.stack.qa.repository
        : this.stack.dev.repository;
    const branch =
      conversationField === "qaConversationId"
        ? this.stack.qa.default_branch
        : this.stack.dev.default_branch;

    const existingId = ticket[conversationField];
    if (!existingId) {
      const start = await client.startConversation({
        message,
        repository: repo,
        branch,
      });
      const convId = await client.waitForConversation(start.id);
      ticket[conversationField] = convId;
      this.store.log(
        ticket,
        conversationField === "qaConversationId"
          ? `Started QA conversation ${convId} on worker`
          : `Started conversation ${convId}`,
      );
    } else {
      await client.sendMessage(existingId, message);
      this.store.log(ticket, `Sent message to ${conversationField} ${existingId}`);
    }
    this.store.save(ticket);
    await this.postConversationLink(ticket, conversationField, client);
  }

  async handleInReview(ticket: TicketRecord): Promise<void> {
    if (ticket.conversationId) {
      await this.openhands.sendMessage(ticket.conversationId, buildInReviewNotice(ticket));
      this.store.log(ticket, "Posted In Review notice to conversation.");
    }
    await this.postAccessBundle(ticket, "in_review");
  }

  async refreshAccessLinks(ticket: TicketRecord, reason: string): Promise<void> {
    if (!ticket.conversationId) return;
    await sleep(3000);
    const urls = await this.openhands.getAccessUrls(ticket.conversationId);
    ticket.accessUrls = urls;
    this.store.log(ticket, `Refreshed access links (${reason}): ${urls.length} URLs`);
    this.store.save(ticket);
    await this.postAccessBundle(ticket, reason);
  }

  private async postConversationLink(
    ticket: TicketRecord,
    field: "conversationId" | "qaConversationId" = "conversationId",
    client: OpenHandsClient = this.openhands,
  ): Promise<void> {
    const conversationId = ticket[field];
    if (!conversationId) return;
    const url = client.conversationPublicUrl(conversationId);
    const label = field === "qaConversationId" ? "QA conversation" : "Conversation";
    const tpl = this.workflow.jira.comments.conversation;
    await this.jira.addComment(ticket.ticketKey, `${label}: ${tpl.replace("{url}", url)}`);
  }

  private async postAccessBundle(ticket: TicketRecord, reason: string): Promise<void> {
    const { comments } = this.workflow.jira;
    const lines: string[] = [`*Sandbox access* (${reason})`, ""];

    if (ticket.conversationId) {
      lines.push(
        comments.conversation.replace(
          "{url}",
          this.openhands.conversationPublicUrl(ticket.conversationId),
        ),
      );
    }
    if (ticket.qaConversationId && ticket.workerIp) {
      const qaCanvas = new OpenHandsClient(this.env, {
        baseUrl: `http://${ticket.workerIp}:8000`,
        publicUrl: `http://${ticket.workerIp}:8000`,
      });
      lines.push(`QA chat: ${qaCanvas.conversationPublicUrl(ticket.qaConversationId)}`);
    }
    if (ticket.pmmServerUrl) {
      lines.push(comments.test_instance.replace("{url}", ticket.pmmServerUrl));
    }
    if (ticket.devPrUrl) {
      lines.push(comments.dev_pr.replace("{url}", ticket.devPrUrl));
    }
    if (ticket.workerIp) {
      lines.push(`QA worker IP: ${ticket.workerIp}`);
    }

    for (const u of ticket.accessUrls) {
      if (/ssh/i.test(u.name)) {
        lines.push(comments.ssh_access.replace("{url}", u.url).replace("{host}", u.url));
      }
      if (/vscode|code|editor/i.test(u.name)) {
        lines.push(`VS Code: ${u.url}`);
      }
    }

    const body = comments.access_bundle
      ? comments.access_bundle.replace("{reason}", reason).replace("{links}", lines.join("\n"))
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
