import type { Env, JiraWorkflowConfig, StackConfig } from "./config.js";
import { ticketChatUrl } from "./chat-bootstrap.js";
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
import { FbResolver } from "./fb-resolver.js";
import { JiraClient } from "./jira-client.js";
import { LinodeRunnerClient } from "./linode-runner.js";
import { OpenHandsClient } from "./openhands-client.js";
import { TicketStore, type TicketPhase, type TicketRecord } from "./ticket-store.js";

export type TransitionInput = {
  ticketKey: string;
  statusName: string;
  issue?: IssueContext;
};

const RESUME_PHASES: TicketPhase[] = ["ready_for_refinement", "in_progress", "in_qa"];
const RUNNER_REQUIRED_PHASES: TicketPhase[] = ["in_qa", "ready_for_merge"];
const RESUME_COOLDOWN_MS = 120_000;

export class WorkflowEngine {
  private readonly store: TicketStore;
  private readonly jira: JiraClient;
  private readonly fb: FbResolver;
  private readonly runner: LinodeRunnerClient;
  private readonly resumeInFlight = new Set<string>();
  private readonly resumeLastAttempt = new Map<string, number>();

  constructor(
    private readonly env: Env,
    private readonly stack: StackConfig,
    private readonly workflow: JiraWorkflowConfig,
  ) {
    this.store = new TicketStore(`${env.dataDir}/tickets`);
    this.jira = new JiraClient(env);
    this.fb = new FbResolver(env);
    this.runner = new LinodeRunnerClient(env, stack);
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
      case "ready_for_refinement": {
        await this.dispatchCommand(ticket, buildProposePrompt(ticket, this.stack, input.issue ?? {}));
        break;
      }
      case "ready_for_work":
        this.store.log(ticket, "Human gate: PO reviews spec PR.");
        break;
      case "in_progress": {
        await this.syncFbArtifacts(ticket, false);
        await this.dispatchCommand(ticket, buildApplyPrompt(ticket, this.stack, input.issue ?? {}));
        break;
      }
      case "in_review":
        await this.syncFbArtifacts(ticket, false);
        await this.handleInReview(ticket);
        break;
      case "in_qa":
        await this.handleInQa(ticket, input.issue ?? {});
        break;
      case "ready_for_merge": {
        await this.ensureRunner(ticket);
        await this.dispatchCommand(ticket, buildFinalizePrompt(ticket, this.stack));
        await this.dispatchCommand(ticket, buildArchivePrompt(ticket));
        await this.teardownRunner(ticket);
        ticket.phase = "done";
        this.store.save(ticket);
        break;
      }
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
    if (!this.runner.enabled) {
      await this.jira.addComment(
        ticket.ticketKey,
        "LINODE_TOKEN not configured — cannot provision sandbox runner. Set LINODE_TOKEN on control plane and re-transition to In QA.",
      );
      return;
    }

    await this.ensureRunner(ticket);
    await this.syncFbArtifacts(ticket, true);

    if (!ticket.fbServerImage || !ticket.fbClientImage) {
      throw new Error("FB images required before QA");
    }

    const runnerIp = ticket.runnerIp ?? ticket.workerIp;
    await this.jira.addComment(
      ticket.ticketKey,
      runnerIp
        ? `QA sandbox runner ready (${runnerIp}, Linode ${ticket.runnerLinodeId}). Chat stays on the control plane — use the ticket chat link below.`
        : `QA sandbox runner provisioning (Linode ${ticket.runnerLinodeId}). Chat stays on the control plane.`,
    );

    const qaPrompt = [
      buildQaPrompt(ticket, this.stack, ctx),
      runnerIp
        ? `\nSandbox runner (PMM test host): ${runnerIp}\nUse this host for pmm-framework / Playwright against a live PMM instance.`
        : "",
    ]
      .filter(Boolean)
      .join("\n");
    await this.dispatchCommand(ticket, qaPrompt);
    await this.postAccessBundle(ticket, "in_qa");
  }

  async teardownRunner(ticket: TicketRecord): Promise<void> {
    const linodeId = ticket.runnerLinodeId ?? ticket.workerLinodeId;
    if (!linodeId) return;

    ticket.runnerLinodeId = undefined;
    ticket.runnerIp = undefined;
    ticket.workerLinodeId = undefined;
    ticket.workerIp = undefined;
    ticket.workerHostname = undefined;
    this.store.save(ticket);

    try {
      await this.runner.destroy(linodeId);
      this.store.log(ticket, `Destroyed runner Linode ${linodeId}`);
      await this.jira.addComment(ticket.ticketKey, `Sandbox runner destroyed (Linode ${linodeId}).`);
    } catch (err) {
      this.store.log(ticket, `Runner destroy failed: ${err instanceof Error ? err.message : String(err)}`);
    }
  }

  async dispatchCommand(ticket: TicketRecord, message: string): Promise<void> {
    const client = this.controlPlaneCanvas();

    const repo = this.stack.dev.repository;
    const branch = this.stack.dev.default_branch;

    if (!ticket.conversationId) {
      const start = await client.startConversation({
        message,
        repository: repo,
        branch,
      });
      const convId = await client.waitForConversation(start.id);
      ticket.conversationId = convId;
      this.store.log(ticket, `Started conversation ${convId} on central chat`);
    } else {
      await client.sendMessage(ticket.conversationId, message);
      this.store.log(ticket, `Sent message to conversation ${ticket.conversationId}`);
    }
    this.store.save(ticket);
    await this.postConversationLink(ticket);
  }

  async handleInReview(ticket: TicketRecord): Promise<void> {
    if (ticket.conversationId) {
      await this.controlPlaneCanvas().sendMessage(ticket.conversationId, buildInReviewNotice(ticket));
      this.store.log(ticket, "Posted In Review notice to conversation.");
    }
    await this.postAccessBundle(ticket, "in_review");
  }

  async refreshAccessLinks(ticket: TicketRecord, reason: string): Promise<void> {
    if (!ticket.conversationId) return;
    const canvas = this.controlPlaneCanvas();
    await sleep(3000);
    const urls = await canvas.getAccessUrls(ticket.conversationId);
    ticket.accessUrls = urls;
    this.store.log(ticket, `Refreshed access links (${reason}): ${urls.length} URLs`);
    this.store.save(ticket);
    await this.postAccessBundle(ticket, reason);
  }

  /** Fire-and-forget: reprovision dead runners or restart stalled phases on chat/API visit. */
  resumeIfStalled(ticketKey: string): void {
    const key = ticketKey.toUpperCase();
    if (this.resumeInFlight.has(key)) return;

    const last = this.resumeLastAttempt.get(key) ?? 0;
    if (Date.now() - last < RESUME_COOLDOWN_MS) return;

    const ticket = this.store.get(key);
    if (!ticket || ticket.phase === "done" || ticket.phase === "ready_for_work") return;
    if (!RESUME_PHASES.includes(ticket.phase)) return;

    this.resumeLastAttempt.set(key, Date.now());
    this.resumeInFlight.add(key);
    void this.checkAndResume(ticket).finally(() => this.resumeInFlight.delete(key));
  }

  private async checkAndResume(ticket: TicketRecord): Promise<void> {
    if (ticket.conversationId && !(await this.conversationExistsOnControlPlane(ticket))) {
      this.store.log(
        ticket,
        `Conversation ${ticket.conversationId} not on control plane — clearing for recreation`,
      );
      ticket.conversationId = undefined;
      this.store.save(ticket);
    }

    const stalled = await this.isRunnerStalled(ticket);
    if (!stalled) return;

    const statusName = this.statusForPhase(ticket.phase);
    if (!statusName) return;
    this.store.log(ticket, "Auto-resuming stalled ticket (conversation or sandbox runner missing)");
    try {
      await this.handleTransition({
        ticketKey: ticket.ticketKey,
        statusName,
        issue: {},
      });
    } catch (err) {
      const fresh = this.store.get(ticket.ticketKey);
      if (fresh) {
        this.store.log(
          fresh,
          `Auto-resume failed: ${err instanceof Error ? err.message : String(err)}`,
        );
      }
    }
  }

  private async isRunnerStalled(ticket: TicketRecord): Promise<boolean> {
    if (!ticket.conversationId) return true;
    if (!(await this.conversationExistsOnControlPlane(ticket))) return true;
    if (!RUNNER_REQUIRED_PHASES.includes(ticket.phase)) return false;

    const linodeId = ticket.runnerLinodeId ?? ticket.workerLinodeId;
    const ip = ticket.runnerIp ?? ticket.workerIp;
    if (!linodeId || !ip) return true;

    const exists = await this.runner.instanceExists(linodeId);
    if (!exists) return true;
    return !(await this.runner.isRunnerReachable(ip));
  }

  private statusForPhase(phase: TicketPhase): string | undefined {
    const s = this.workflow.jira.statuses;
    const map: Record<TicketPhase, string | undefined> = {
      ready_for_refinement: s.ready_for_refinement,
      ready_for_work: s.ready_for_work,
      in_progress: s.in_progress,
      in_review: s.in_review,
      in_qa: s.in_qa,
      ready_for_merge: s.ready_for_merge,
      done: undefined,
    };
    return map[phase];
  }

  private clearRunnerFields(ticket: TicketRecord): void {
    ticket.runnerLinodeId = undefined;
    ticket.runnerIp = undefined;
    ticket.workerLinodeId = undefined;
    ticket.workerIp = undefined;
    ticket.workerHostname = undefined;
  }

  private async ensureRunner(ticket: TicketRecord): Promise<void> {
    const existingIp = ticket.runnerIp ?? ticket.workerIp;
    const linodeId = ticket.runnerLinodeId ?? ticket.workerLinodeId;

    if (linodeId && existingIp) {
      const exists = await this.runner.instanceExists(linodeId);
      const healthy = exists && (await this.runner.isRunnerReachable(existingIp));
      if (healthy) {
        ticket.runnerIp = existingIp;
        return;
      }

      this.store.log(
        ticket,
        `Stale sandbox runner (Linode ${linodeId}, ${existingIp}) — reprovisioning`,
      );
      this.clearRunnerFields(ticket);
      this.store.save(ticket);
    }

    if (!this.runner.enabled) {
      throw new Error(
        "LINODE_TOKEN not configured — cannot provision sandbox runner. Set LINODE_TOKEN on the control plane.",
      );
    }
    if (!this.env.workerRootPassword) {
      throw new Error("WORKER_ROOT_PASSWORD required to create runner Linodes");
    }

    await this.jira.addComment(
      ticket.ticketKey,
      "Provisioning sandbox runner for QA/test execution (workspace on remote VM, chat stays on control plane)…",
    );

    const provisioned = await this.runner.provisionRunner(ticket.ticketKey);
    ticket.runnerLinodeId = provisioned.linodeId;
    ticket.runnerIp = provisioned.ip;
    ticket.workerLinodeId = provisioned.linodeId;
    ticket.workerIp = provisioned.ip;
    this.store.save(ticket);

    await this.jira.addComment(
      ticket.ticketKey,
      `Sandbox runner ready at ${provisioned.ip} (Linode ${provisioned.linodeId}). Central chat: ${ticketChatUrl(this.env, ticket.ticketKey)}`,
    );

    const ready = await this.runner.waitUntilRunnerReady(provisioned.ip);
    if (!ready) {
      await this.jira.addComment(
        ticket.ticketKey,
        `Sandbox runner ${provisioned.ip}: SSH did not become reachable within timeout.`,
      );
    }
  }

  /** Central control-plane Canvas — all ticket conversations live here. */
  private controlPlaneCanvas(): OpenHandsClient {
    return new OpenHandsClient(this.env);
  }

  private async conversationExistsOnControlPlane(ticket: TicketRecord): Promise<boolean> {
    if (!ticket.conversationId) return false;
    try {
      await this.controlPlaneCanvas().getConversation(ticket.conversationId);
      return true;
    } catch {
      return false;
    }
  }

  private async postConversationLink(ticket: TicketRecord): Promise<void> {
    if (!ticket.conversationId) return;
    const url = ticketChatUrl(this.env, ticket.ticketKey);
    const tpl = this.workflow.jira.comments.conversation;
    await this.jira.addComment(ticket.ticketKey, `Conversation: ${tpl.replace("{url}", url)}`);
  }

  private async postAccessBundle(ticket: TicketRecord, reason: string): Promise<void> {
    const { comments } = this.workflow.jira;
    const lines: string[] = [`*Sandbox access* (${reason})`, ""];
    if (ticket.conversationId) {
      lines.push(
        comments.conversation.replace("{url}", ticketChatUrl(this.env, ticket.ticketKey)),
      );
    }
    if (ticket.fbServerImage) {
      lines.push(`FB server image: ${ticket.fbServerImage}`);
    }
    if (ticket.fbClientImage) {
      lines.push(`FB client image: ${ticket.fbClientImage}`);
    }
    if (ticket.devPrUrl) {
      lines.push(comments.dev_pr.replace("{url}", ticket.devPrUrl));
    }
    const runnerIp = ticket.runnerIp ?? ticket.workerIp;
    if (runnerIp) {
      lines.push(`Sandbox runner: ${runnerIp}`);
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
