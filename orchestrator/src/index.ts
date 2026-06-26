import express from "express";
import { z } from "zod";
import { chatBootstrapHtml } from "./chat-bootstrap.js";
import { loadEnv, loadJiraWorkflow, loadStackConfig } from "./config.js";
import { WorkflowEngine } from "./workflow-engine.js";

const transitionSchema = z.object({
  ticketKey: z.string().min(1),
  statusName: z.string().min(1),
  summary: z.string().optional(),
  description: z.string().optional(),
  acceptanceCriteria: z.string().optional(),
});

const jiraWebhookSchema = z.object({
  issue: z
    .object({
      key: z.string(),
      fields: z
        .object({
          summary: z.string().optional(),
          description: z.unknown().optional(),
          status: z.object({ name: z.string() }).optional(),
        })
        .optional(),
    })
    .optional(),
  webhookEvent: z.string().optional(),
});

function extractDescription(desc: unknown): string | undefined {
  if (typeof desc === "string") return desc;
  return undefined;
}

type TransitionRequest = {
  ticketKey: string;
  statusName: string;
  issue?: {
    summary?: string;
    description?: string;
    acceptanceCriteria?: string;
  };
};

function scheduleTransition(engine: WorkflowEngine, input: TransitionRequest): void {
  void engine
    .handleTransition({
      ticketKey: input.ticketKey.toUpperCase(),
      statusName: input.statusName,
      issue: input.issue,
    })
    .catch((err) => engine.recordTransitionFailure(input.ticketKey, input.statusName, err));
}

function main() {
  const env = loadEnv();
  const stack = loadStackConfig(env.stackConfigPath);
  const workflow = loadJiraWorkflow(env.jiraWorkflowPath);
  const engine = new WorkflowEngine(env, stack, workflow);

  const app = express();
  app.use(express.json({ limit: "2mb" }));

  const auth = (req: express.Request, res: express.Response, next: express.NextFunction) => {
    const key = req.header("x-api-key");
    if (key !== env.orchestratorApiKey) {
      res.status(401).json({ error: "Unauthorized" });
      return;
    }
    next();
  };

  const api = express.Router();
  api.get("/health", (_req, res) => {
    res.json({ ok: true, trigger: stack.lifecycle.trigger, sandboxMode: stack.sandbox.mode });
  });

  api.get("/tickets", auth, (_req, res) => {
    res.json(engine.listTickets());
  });

  api.get("/tickets/:key", auth, (req, res) => {
    const key = String(req.params.key).toUpperCase();
    const ticket = engine.getTicket(key);
    if (!ticket) {
      res.status(404).json({ error: "Not found" });
      return;
    }
    engine.resumeIfStalled(key);
    res.json(engine.getTicket(key) ?? ticket);
  });

  api.post("/tickets/transition", auth, (req, res) => {
    try {
      const input = transitionSchema.parse(req.body);
      const ticketKey = input.ticketKey.toUpperCase();
      scheduleTransition(engine, {
        ticketKey,
        statusName: input.statusName,
        issue: {
          summary: input.summary,
          description: input.description,
          acceptanceCriteria: input.acceptanceCriteria,
        },
      });
      res.status(202).json({ accepted: true, ticketKey, statusName: input.statusName });
    } catch (err) {
      res.status(400).json({ error: err instanceof Error ? err.message : String(err) });
    }
  });

  api.post("/tickets/:key/links", auth, async (req, res) => {
    try {
      const body = z
        .object({
          specPrUrl: z.string().url().optional(),
          devPrUrl: z.string().url().optional(),
          qaPrUrl: z.string().url().optional(),
        })
        .parse(req.body);
      const ticket = await engine.updateTicketLinks(String(req.params.key).toUpperCase(), body);
      res.json(ticket);
    } catch (err) {
      res.status(400).json({ error: err instanceof Error ? err.message : String(err) });
    }
  });

  api.post("/tickets/:key/refresh-access", auth, async (req, res) => {
    const key = String(req.params.key).toUpperCase();
    const ticket = engine.getTicket(key);
    if (!ticket?.conversationId) {
      res.status(404).json({ error: "Ticket or conversation not found" });
      return;
    }
    await engine.refreshAccessLinks(ticket, "manual");
    res.json(engine.getTicket(key));
  });

  app.use("/orchestrator", api);

  app.get("/tickets/:key/chat", (req, res) => {
    const key = String(req.params.key).toUpperCase();
    const ticket = engine.getTicket(key);
    if (!ticket) {
      res.status(404).send(`Ticket ${key} not found.`);
      return;
    }
    engine.resumeIfStalled(key);
    res.type("html").send(chatBootstrapHtml(engine.getTicket(key) ?? ticket, env));
  });

  app.post("/hooks/jira", (req, res) => {
    if (env.jiraWebhookSecret) {
      const secret = req.header("x-webhook-secret");
      if (secret !== env.jiraWebhookSecret) {
        res.status(401).json({ error: "Invalid webhook secret" });
        return;
      }
    }

    try {
      const payload = jiraWebhookSchema.parse(req.body);
      const key = payload.issue?.key;
      const statusName = payload.issue?.fields?.status?.name;
      if (!key || !statusName) {
        res.status(400).json({ error: "Missing issue key or status" });
        return;
      }

      const ticketKey = key.toUpperCase();
      scheduleTransition(engine, {
        ticketKey,
        statusName,
        issue: {
          summary: payload.issue?.fields?.summary,
          description: extractDescription(payload.issue?.fields?.description),
        },
      });
      res.status(202).json({ accepted: true, ticketKey, statusName });
    } catch (err) {
      res.status(400).json({ error: err instanceof Error ? err.message : String(err) });
    }
  });

  app.listen(env.orchestratorPort, () => {
    console.log(`Orchestrator listening on :${env.orchestratorPort}`);
    console.log(`Dev repo: ${stack.dev.repository}`);
    console.log(`QA repo: ${stack.qa.repository}`);
    console.log(`Sandbox mode: ${stack.sandbox.mode}`);
    console.log(`Canvas UI: ${env.agentCanvasPublicUrl}`);
    console.log(`Jira webhook: POST /hooks/jira`);
    console.log(`Health: GET /orchestrator/health`);
    console.log(`Transition: POST /orchestrator/tickets/transition`);
  });
}

main();
