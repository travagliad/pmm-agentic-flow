import fs from "node:fs";
import type { TicketRecord } from "./ticket-store.js";

const AGENT_STATE_PATH = "/projects/.agent/state.json";

type AgentState = {
  ticket?: string;
  specPrUrl?: string;
  devPrUrl?: string;
};

export function readAgentState(ticketKey: string): AgentState | undefined {
  if (!fs.existsSync(AGENT_STATE_PATH)) return undefined;
  try {
    const raw = JSON.parse(fs.readFileSync(AGENT_STATE_PATH, "utf8")) as AgentState;
    if (raw.ticket && raw.ticket.toUpperCase() !== ticketKey.toUpperCase()) return undefined;
    return raw;
  } catch {
    return undefined;
  }
}

/** Pull PR URLs written by the agent into orchestrator ticket store before apply. */
export function mergeAgentStateIntoTicket(ticket: TicketRecord): void {
  const state = readAgentState(ticket.ticketKey);
  if (!state) return;
  if (state.specPrUrl && !ticket.specPrUrl) ticket.specPrUrl = state.specPrUrl;
  if (state.devPrUrl && !ticket.devPrUrl) ticket.devPrUrl = state.devPrUrl;
}
