import express from "express";
import { z } from "zod";
import { loadEnv, loadJiraWorkflow, loadLoopConfig } from "./config.js";
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

function main() {
  const env = loadEnv();
  const loop = loadLoopConfig(env.loopConfigPath);
  const workflow = loadJiraWorkflow(env.jiraWorkflowPath);
  const engine = new WorkflowEngine(env, loop, workflow);

  const app = express();
  app.use(express.json({ limit: "2mb" }));

  app.get("/health", (_req, res) => {
    res.json({ ok: true, trigger: loop.lifecycle.trigger });
  });

  const auth = (req: express.Request, res: express.Response, next: express.NextFunction) => {
    const key = req.header("x-api-key");
    if (key !== env.orchestratorApiKey) {
      res.status(401).json({ error: "Unauthorized" });
      return;
    }
    next();
  };

  app.get("/api/tickets", auth, (_req, res) => {
    res.json(engine.listTickets());
  });

  app.get("/api/tickets/:key", auth, (req, res) => {
    const key = String(req.params.key).toUpperCase();
    const ticket = engine.getTicket(key);
    if (!ticket) {
      res.status(404).json({ error: "Not found" });
      return;
    }
    res.json(ticket);
  });

  app.post("/api/tickets/transition", auth, async (req, res) => {
    try {
      const input = transitionSchema.parse(req.body);
      const ticket = await engine.handleTransition({
        ticketKey: input.ticketKey.toUpperCase(),
        statusName: input.statusName,
        issue: {
          summary: input.summary,
          description: input.description,
          acceptanceCriteria: input.acceptanceCriteria,
        },
      });
      res.status(202).json(ticket);
    } catch (err) {
      res.status(400).json({ error: err instanceof Error ? err.message : String(err) });
    }
  });

  app.post("/hooks/jira", async (req, res) => {
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

      const ticket = await engine.handleTransition({
        ticketKey: key,
        statusName,
        issue: {
          summary: payload.issue?.fields?.summary,
          description: extractDescription(payload.issue?.fields?.description),
        },
      });
      res.status(202).json(ticket);
    } catch (err) {
      res.status(400).json({ error: err instanceof Error ? err.message : String(err) });
    }
  });

  app.post("/api/tickets/:key/links", auth, async (req, res) => {
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

  app.post("/api/tickets/:key/refresh-access", auth, async (req, res) => {
    const key = String(req.params.key).toUpperCase();
    const ticket = engine.getTicket(key);
    if (!ticket?.conversationId) {
      res.status(404).json({ error: "Ticket or conversation not found" });
      return;
    }
    await engine.refreshAccessLinks(ticket, "manual");
    res.json(engine.getTicket(key));
  });

  app.listen(env.orchestratorPort, () => {
    console.log(`Orchestrator listening on :${env.orchestratorPort}`);
    console.log(`Dev repo: ${loop.dev.repository}`);
    console.log(`QA repo: ${loop.qa.repository}`);
    console.log(`Jira webhook: POST /hooks/jira`);
    console.log(`Orchestrator health: GET /loop/health (via Caddy)`);
    console.log(`Manual transition: POST /loop/api/tickets/transition`);
  });
}

main();
