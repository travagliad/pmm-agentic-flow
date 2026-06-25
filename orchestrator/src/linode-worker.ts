import type { Env } from "./config.js";
import type { FbArtifacts } from "./fb-resolver.js";

export type WorkerRecord = {
  linodeId: number;
  ip: string;
  hostname: string;
  pmmUrl: string;
};

export class LinodeWorkerClient {
  constructor(private readonly env: Env) {}

  get enabled(): boolean {
    return Boolean(this.env.linodeToken);
  }

  async provisionQaWorker(ticketKey: string, fb: FbArtifacts): Promise<WorkerRecord> {
    if (!this.enabled) {
      throw new Error("LINODE_TOKEN not set — cannot provision QA worker");
    }

    const label = `pmm-qa-${ticketKey.toLowerCase()}`.slice(0, 32);
    const userData = this.buildCloudInit(fb);

    const res = await fetch("https://api.linode.com/v4/linode/instances", {
      method: "POST",
      headers: this.headers(),
      body: JSON.stringify({
        label,
        region: this.env.workerLinodeRegion,
        type: this.env.workerLinodeType,
        image: "linode/ubuntu24.04",
        root_pass: this.env.workerRootPassword,
        tags: ["pmm-agentic-flow", "qa-worker", ticketKey.toLowerCase()],
        metadata: { user_data: Buffer.from(userData).toString("base64") },
      }),
    });

    if (!res.ok) {
      throw new Error(`Linode create failed (${res.status}): ${await res.text()}`);
    }

    const created = (await res.json()) as { id: number; ipv4?: string[] };
    const ip = await this.waitForIp(created.id);
    const pmmUrl = `https://${ip}:8443/`;

    return { linodeId: created.id, ip, hostname: ip, pmmUrl };
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
    return `#cloud-config
package_update: true
packages:
  - curl
  - ca-certificates
runcmd:
  - curl -fsSL https://get.docker.com | sh
  - systemctl enable docker
  - systemctl start docker
  - docker pull ${fb.serverImage}
  - docker run -d --name pmm-server --restart unless-stopped -p 8443:8443 -p 8081:8080 ${fb.serverImage}
  - echo "PMM QA worker ready" > /var/log/pmm-qa-worker-ready.log
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
