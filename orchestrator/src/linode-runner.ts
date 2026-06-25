import net from "node:net";
import type { Env, StackConfig } from "./config.js";
import { linodeRunnerSettings } from "./config.js";

export type RunnerRecord = {
  linodeId: number;
  ip: string;
};

export class LinodeRunnerClient {
  private readonly region: string;
  private readonly type: string;

  constructor(
    private readonly env: Env,
    stack: StackConfig,
  ) {
    const linode = linodeRunnerSettings(stack);
    this.region = linode.region;
    this.type = linode.runner_type;
  }

  get enabled(): boolean {
    return Boolean(this.env.linodeToken);
  }

  async provisionRunner(ticketKey: string): Promise<RunnerRecord> {
    if (!this.enabled) {
      throw new Error("LINODE_TOKEN not set — cannot provision QA runner");
    }
    if (!this.env.workerRootPassword) {
      throw new Error("WORKER_ROOT_PASSWORD required to create runner Linodes");
    }

    const label = runnerLabel(ticketKey);
    const existing = await this.findRunnerByLabel(label);
    if (existing) {
      const ip = existing.ipv4?.[0] ?? (await this.waitForIp(existing.id));
      return { linodeId: existing.id, ip };
    }

    const userData = this.buildCloudInit(ticketKey);

    const res = await fetch("https://api.linode.com/v4/linode/instances", {
      method: "POST",
      headers: this.headers(),
      body: JSON.stringify({
        label,
        region: this.region,
        type: this.type,
        image: "linode/ubuntu24.04",
        root_pass: this.env.workerRootPassword,
        tags: ["agentic-flow", "qa-runner", ticketKey.toLowerCase()],
        metadata: { user_data: Buffer.from(userData).toString("base64") },
      }),
    });

    if (!res.ok) {
      const body = await res.text();
      if (res.status === 400 && body.includes("Label must be unique")) {
        const retry = await this.findRunnerByLabel(label);
        if (retry) {
          const ip = retry.ipv4?.[0] ?? (await this.waitForIp(retry.id));
          return { linodeId: retry.id, ip };
        }
      }
      throw new Error(`Linode create failed (${res.status}): ${body}`);
    }

    const created = (await res.json()) as { id: number };
    const ip = await this.waitForIp(created.id);

    return { linodeId: created.id, ip };
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

  async instanceExists(linodeId: number): Promise<boolean> {
    if (!this.enabled) return false;
    const res = await fetch(`https://api.linode.com/v4/linode/instances/${linodeId}`, {
      headers: this.headers(),
    });
    return res.ok;
  }

  async isRunnerReachable(ip: string, timeoutMs = 10_000): Promise<boolean> {
    return tcpReachable(ip, 22, timeoutMs);
  }

  async waitUntilRunnerReady(ip: string, timeoutMs = 900_000): Promise<boolean> {
    const started = Date.now();
    while (Date.now() - started < timeoutMs) {
      if (await this.isRunnerReachable(ip, 8000)) return true;
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

  private buildCloudInit(ticketKey: string): string {
    return `#cloud-config
package_update: true
packages:
  - git
  - ca-certificates
  - curl

write_files:
  - path: /etc/pmm-agentic-flow/runner.env
    permissions: "0600"
    content: |
      TICKET_KEY=${ticketKey}
      GITHUB_TOKEN=${this.env.githubToken}
      BOOTSTRAP_DEST=/opt/pmm-agentic-flow/src

runcmd:
  - mkdir -p /opt/pmm-agentic-flow /var/lib/pmm-agentic-flow
  - git clone ${this.env.bootstrapRepoUrl} /opt/pmm-agentic-flow/src
  - bash /opt/pmm-agentic-flow/src/deploy/bootstrap-runner.sh 2>&1 | tee /var/log/pmm-agentic-flow-runner-bootstrap.log
`;
  }

  private async findRunnerByLabel(
    label: string,
  ): Promise<{ id: number; ipv4?: string[]; status?: string } | undefined> {
    const res = await fetch("https://api.linode.com/v4/linode/instances", {
      headers: {
        ...this.headers(),
        "X-Filter": JSON.stringify({ "+and": [{ label }] }),
      },
    });
    if (!res.ok) return undefined;
    const data = (await res.json()) as { data?: Array<{ id: number; ipv4?: string[]; status?: string }> };
    return data.data?.[0];
  }

  private headers(): Record<string, string> {
    return {
      Authorization: `Bearer ${this.env.linodeToken}`,
      "Content-Type": "application/json",
    };
  }
}

function runnerLabel(ticketKey: string): string {
  return `run-${ticketKey.toLowerCase()}`.slice(0, 32);
}

function tcpReachable(host: string, port: number, timeoutMs: number): Promise<boolean> {
  return new Promise((resolve) => {
    const socket = net.createConnection({ host, port });
    const done = (ok: boolean) => {
      socket.removeAllListeners();
      socket.destroy();
      resolve(ok);
    };
    socket.setTimeout(timeoutMs);
    socket.on("connect", () => done(true));
    socket.on("timeout", () => done(false));
    socket.on("error", () => done(false));
  });
}

function sleep(ms: number) {
  return new Promise((r) => setTimeout(r, ms));
}
