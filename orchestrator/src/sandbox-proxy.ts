import type { Server } from "node:http";
import type { IncomingMessage } from "node:http";
import type { Socket } from "node:net";
import httpProxy from "http-proxy";
import type { Express, Request, Response } from "express";
import type { TicketRecord } from "./ticket-store.js";

/** @deprecated Debug-only — not wired in index.ts. Runners are QA VMs, not Canvas backends. */

export type TicketLookup = (ticketKey: string) => TicketRecord | undefined;

function runnerTarget(ticket: TicketRecord): string | undefined {
  const ip = ticket.runnerIp ?? ticket.workerIp;
  if (!ip) return undefined;
  return `http://${ip}:8000`;
}

function ticketKeyFromPath(path: string): string | undefined {
  const match = path.match(/^\/sandbox\/([^/]+)/);
  return match?.[1]?.toUpperCase();
}

export function attachSandboxProxy(
  app: Express,
  lookup: TicketLookup,
): { proxy: httpProxy; attachUpgrade: (server: Server) => void } {
  const proxy = httpProxy.createProxyServer({
    ws: true,
    xfwd: true,
    proxyTimeout: 86_400_000,
  });

  proxy.on("error", (_err, _req, res) => {
    if (res && "writeHead" in res && !res.headersSent) {
      res.writeHead(502, { "Content-Type": "text/plain" });
      res.end("Sandbox unreachable");
    }
  });

  app.use("/sandbox/:ticketKey", (req: Request, res: Response) => {
    const ticketKey = String(req.params.ticketKey).toUpperCase();
    const ticket = lookup(ticketKey);
    const target = ticket ? runnerTarget(ticket) : undefined;
    if (!target) {
      res.status(404).json({ error: `Sandbox not found for ${ticketKey}` });
      return;
    }

    proxy.web(req, res, { target, changeOrigin: true });
  });

  const attachUpgrade = (server: Server) => {
    server.on("upgrade", (req: IncomingMessage, socket: Socket, head: Buffer) => {
      const key = ticketKeyFromPath(req.url ?? "");
      if (!key) {
        socket.destroy();
        return;
      }
      const ticket = lookup(key);
      const target = ticket ? runnerTarget(ticket) : undefined;
      if (!target) {
        socket.destroy();
        return;
      }
      proxy.ws(req, socket, head, { target, changeOrigin: true });
    });
  };

  return { proxy, attachUpgrade };
}
