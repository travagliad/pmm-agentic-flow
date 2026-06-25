import type { Env, StackConfig } from "./config.js";
import { chatsPerWorker, linodeWorkerSettings } from "./config.js";
import type { FbArtifacts } from "./fb-resolver.js";
import type { WorkerPoolRecord } from "./worker-store.js";

export type WorkerRecord = {
  linodeId: number;
  ip: string;
  hostname: string;
  pmmUrl: string;
  canvasBaseUrl: string;
  canvasPublicUrl: string;
};

export class LinodeWorkerClient {
  private readonly region: string;
  private readonly type: string;
  private readonly maxChats: number;

  constructor(
    private readonly env: Env,
    stack: StackConfig,
  ) {
    const linode = linodeWorkerSettings(stack);
    this.region = linode.region;
    this.type = linode.worker_type;
    this.maxChats = chatsPerWorker(stack);
  }

  get enabled(): boolean {
    return Boolean(this.env.linodeToken);
  }

  get chatsPerWorker(): number {
    return this.maxChats;
  }

  async provisionQaWorker(ticketKey: string, fb: FbArtifacts): Promise<WorkerRecord> {
    if (!this.enabled) {
      throw new Error("LINODE_TOKEN not set — cannot provision QA worker");
    }

    const label = `qa-${ticketKey.toLowerCase()}`.slice(0, 32);
    const userData = this.buildCloudInit(fb);

    const res = await fetch("https://api.linode.com/v4/linode/instances", {
      method: "POST",
      headers: this.headers(),
      body: JSON.stringify({
        label,
        region: this.region,
        type: this.type,
        image: "linode/ubuntu24.04",
        root_pass: this.env.workerRootPassword,
        tags: ["agentic-flow", "qa-worker", ticketKey.toLowerCase()],
        metadata: { user_data: Buffer.from(userData).toString("base64") },
      }),
    });

    if (!res.ok) {
      throw new Error(`Linode create failed (${res.status}): ${await res.text()}`);
    }

    const created = (await res.json()) as { id: number; ipv4?: string[] };
    const ip = await this.waitForIp(created.id);
    const canvasBaseUrl = `http://${ip}:8000`;
    const canvasPublicUrl = `http://${ip}:8000`;
    const pmmUrl = `https://${ip}:8443/`;

    return {
      linodeId: created.id,
      ip,
      hostname: ip,
      pmmUrl,
      canvasBaseUrl,
      canvasPublicUrl,
    };
  }

  toPoolRecord(worker: WorkerRecord, ticketKeys: string[]): WorkerPoolRecord {
    return {
      linodeId: worker.linodeId,
      ip: worker.ip,
      label: `qa-pool-${worker.linodeId}`,
      canvasBaseUrl: worker.canvasBaseUrl,
      canvasPublicUrl: worker.canvasPublicUrl,
      pmmUrl: worker.pmmUrl,
      ticketKeys,
      maxChats: this.maxChats,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };
  }

  async destroy(linodeId: number): Promise<void> {
    if (!this.enabled) return;
    const res = await fetch(`https://api.linode.com/v4/linode/instances/${linodeId}`, {
      method: "DELETE",
      headers: this.headers(),
    });
    if (!res.ok && res.status !== 404) {
      throw new Error(`Linode delete failed (${res.status}): ${await res.text()}`);
    }
  }

  async waitUntilCanvasReady(ip: string, timeoutMs = 900_000): Promise<boolean> {
    const started = Date.now();
    const url = `http://${ip}:8000/health`;
    while (Date.now() - started < timeoutMs) {
      try {
        const res = await fetch(url, { method: "GET", signal: AbortSignal.timeout(8000) });
        if (res.ok) return true;
      } catch {
        // still booting
      }
      await sleep(15_000);
    }
    return false;
  }

  async waitUntilPmmReady(ip: string, timeoutMs = 900_000): Promise<boolean> {
    const started = Date.now();
    const url = `https://${ip}:8443/`;
    while (Date.now() - started < timeoutMs) {
      try {
        const res = await fetch(url, { method: "GET", signal: AbortSignal.timeout(8000) });
        if (res.ok || res.status === 401 || res.status === 302) return true;
      } catch {
        // PMM still booting
      }
      await sleep(15_000);
    }
    return false;
  }

  private async waitForIp(linodeId: number, timeoutMs = 300_000): Promise<string> {
    const started = Date.now();
    while (Date.now() - started < timeoutMs) {
      const res = await fetch(`https://api.linode.com/v4/linode/instances/${linodeId}`, {
        headers: this.headers(),
      });
      if (!res.ok) throw new Error(`Linode get failed (${res.status})`);
      const data = (await res.json()) as { ipv4?: string[]; status?: string };
      const ip = data.ipv4?.[0];
      if (ip && data.status === "running") return ip;
      await sleep(5000);
    }
    throw new Error(`Timed out waiting for Linode ${linodeId} IP`);
  }

  private buildCloudInit(fb: FbArtifacts): string {
    const secret = this.env.agentCanvasSecretKey ?? "";
    const copilot = this.env.githubCopilotToken ?? this.env.githubToken;
    const cursor = this.env.cursorApiKey ?? "";
    const version = this.env.agentCanvasVersion;

    return `#cloud-config
package_update: true
packages:
  - git
  - ca-certificates
  - curl

write_files:
  - path: /etc/pmm-agentic-flow/worker.env
    permissions: "0600"
    content: |
      AGENT_CANVAS_PUBLIC_URL=http://__WORKER_IP__:8000
      AGENT_CANVAS_VERSION=${version}
      LOCAL_BACKEND_API_KEY=${this.env.agentCanvasApiKey}
      AGENT_CANVAS_API_KEY=${this.env.agentCanvasApiKey}
      OH_SECRET_KEY=${secret}
      AGENT_CANVAS_SECRET_KEY=${secret}
      GITHUB_TOKEN=${this.env.githubToken}
      GITHUB_COPILOT_TOKEN=${copilot}
      CURSOR_API_KEY=${cursor}
      PMM_SERVER_IMAGE=${fb.serverImage}
      BOOTSTRAP_DEST=/opt/pmm-agentic-flow/src

runcmd:
  - mkdir -p /opt/pmm-agentic-flow
  - git clone ${this.env.bootstrapRepoUrl} /opt/pmm-agentic-flow/src
  - bash /opt/pmm-agentic-flow/src/deploy/bootstrap-worker.sh 2>&1 | tee /var/log/pmm-agentic-flow-worker-bootstrap.log
`;
  }

  private headers(): Record<string, string> {
    return {
      Authorization: `Bearer ${this.env.linodeToken}`,
      "Content-Type": "application/json",
    };
  }
}

function sleep(ms: number) {
  return new Promise((r) => setTimeout(r, ms));
}
