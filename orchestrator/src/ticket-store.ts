import fs from "node:fs";
import path from "node:path";
import type { ExposedUrl } from "./openhands-client.js";

export type TicketPhase =
  | "ready_for_refinement"
  | "ready_for_work"
  | "in_progress"
  | "in_review"
  | "in_qa"
  | "ready_for_merge"
  | "done";

export type TicketRecord = {
  ticketKey: string;
  changeId?: string;
  phase: TicketPhase;
  conversationId?: string;
  specPrUrl?: string;
  devPrUrl?: string;
  qaPrUrl?: string;
  submodulesPr?: number;
  fbServerImage?: string;
  fbClientImage?: string;
  workerLinodeId?: number;
  workerIp?: string;
  workerHostname?: string;
  pmmServerUrl?: string;
  accessUrls: ExposedUrl[];
  buildIteration: number;
  createdAt: string;
  updatedAt: string;
  logs: string[];
};

export class TicketStore {
  constructor(private readonly dir: string) {
    fs.mkdirSync(dir, { recursive: true });
  }

  get(ticketKey: string): TicketRecord | undefined {
    const file = this.filePath(ticketKey);
    if (!fs.existsSync(file)) return undefined;
    return JSON.parse(fs.readFileSync(file, "utf8")) as TicketRecord;
  }

  save(record: TicketRecord): void {
    record.updatedAt = new Date().toISOString();
    fs.writeFileSync(this.filePath(record.ticketKey), JSON.stringify(record, null, 2));
  }

  list(): TicketRecord[] {
    return fs
      .readdirSync(this.dir)
      .filter((f) => f.endsWith(".json"))
      .map((f) => JSON.parse(fs.readFileSync(path.join(this.dir, f), "utf8")) as TicketRecord)
      .sort((a, b) => b.updatedAt.localeCompare(a.updatedAt));
  }

  getOrCreate(ticketKey: string, phase: TicketPhase = "ready_for_refinement"): TicketRecord {
    const existing = this.get(ticketKey);
    if (existing) return existing;
    const record: TicketRecord = {
      ticketKey,
      phase,
      accessUrls: [],
      buildIteration: 0,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
      logs: [],
    };
    this.save(record);
    return record;
  }

  log(record: TicketRecord, line: string): void {
    record.logs.push(`[${new Date().toISOString()}] ${line}`);
    this.save(record);
  }

  private filePath(ticketKey: string): string {
    return path.join(this.dir, `${ticketKey.toUpperCase()}.json`);
  }
}
