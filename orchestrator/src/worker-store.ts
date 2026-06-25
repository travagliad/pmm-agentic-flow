import fs from "node:fs";
import path from "node:path";

export type WorkerPoolRecord = {
  linodeId: number;
  ip: string;
  label: string;
  canvasBaseUrl: string;
  canvasPublicUrl: string;
  pmmUrl: string;
  ticketKeys: string[];
  maxChats: number;
  createdAt: string;
  updatedAt: string;
};

export class WorkerStore {
  constructor(private readonly dir: string) {
    fs.mkdirSync(dir, { recursive: true });
  }

  list(): WorkerPoolRecord[] {
    return fs
      .readdirSync(this.dir)
      .filter((f) => f.endsWith(".json"))
      .map((f) => JSON.parse(fs.readFileSync(path.join(this.dir, f), "utf8")) as WorkerPoolRecord);
  }

  get(linodeId: number): WorkerPoolRecord | undefined {
    const file = this.filePath(linodeId);
    if (!fs.existsSync(file)) return undefined;
    return JSON.parse(fs.readFileSync(file, "utf8")) as WorkerPoolRecord;
  }

  save(record: WorkerPoolRecord): void {
    record.updatedAt = new Date().toISOString();
    fs.writeFileSync(this.filePath(record.linodeId), JSON.stringify(record, null, 2));
  }

  findWithCapacity(maxChats: number): WorkerPoolRecord | undefined {
    return this.list().find((w) => w.ticketKeys.length < maxChats);
  }

  assignTicket(linodeId: number, ticketKey: string, maxChats: number): WorkerPoolRecord {
    const worker = this.get(linodeId);
    if (!worker) throw new Error(`Worker ${linodeId} not found`);
    if (worker.ticketKeys.includes(ticketKey)) return worker;
    if (worker.ticketKeys.length >= maxChats) {
      throw new Error(`Worker ${linodeId} is full (${worker.ticketKeys.length}/${maxChats})`);
    }
    worker.ticketKeys.push(ticketKey);
    this.save(worker);
    return worker;
  }

  releaseTicket(linodeId: number, ticketKey: string): WorkerPoolRecord | undefined {
    const worker = this.get(linodeId);
    if (!worker) return undefined;
    worker.ticketKeys = worker.ticketKeys.filter((k) => k !== ticketKey);
    this.save(worker);
    return worker;
  }

  remove(linodeId: number): void {
    const file = this.filePath(linodeId);
    if (fs.existsSync(file)) fs.unlinkSync(file);
  }

  private filePath(linodeId: number): string {
    return path.join(this.dir, `worker-${linodeId}.json`);
  }
}
