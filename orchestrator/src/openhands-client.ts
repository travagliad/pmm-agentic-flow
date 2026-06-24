import type { Env } from "./config.js";

export type StartTask = {
  id: string;
  status: string;
  app_conversation_id?: string;
  error?: string;
};

export type ExposedUrl = { name: string; url: string };

export type AppConversation = {
  id: string;
  status: string;
  selected_repository?: string;
  sandbox_id?: string;
  exposed_urls?: ExposedUrl[];
};

export type SandboxRecord = {
  id: string;
  exposed_urls?: ExposedUrl[];
};

export class OpenHandsClient {
  constructor(private readonly env: Env) {}

  private headers() {
    return {
      Authorization: `Bearer ${this.env.openhandsApiKey}`,
      "Content-Type": "application/json",
    };
  }

  async startConversation(params: {
    message: string;
    repository: string;
    branch?: string;
  }): Promise<StartTask> {
    const body = {
      initial_message: {
        content: [{ type: "text", text: params.message }],
      },
      selected_repository: params.repository,
      ...(params.branch ? { selected_branch: params.branch } : {}),
    };

    const res = await fetch(`${this.env.openhandsBaseUrl}/api/v1/app-conversations`, {
      method: "POST",
      headers: this.headers(),
      body: JSON.stringify(body),
    });

    if (!res.ok) {
      throw new Error(`OpenHands start failed (${res.status}): ${await res.text()}`);
    }

    return (await res.json()) as StartTask;
  }

  async waitForConversation(startTaskId: string, timeoutMs = 600_000): Promise<string> {
    const started = Date.now();
    while (Date.now() - started < timeoutMs) {
      const res = await fetch(
        `${this.env.openhandsBaseUrl}/api/v1/app-conversations/start-tasks/${startTaskId}`,
        { headers: this.headers() },
      );
      if (!res.ok) {
        throw new Error(`OpenHands poll failed (${res.status}): ${await res.text()}`);
      }
      const task = (await res.json()) as StartTask;
      if (task.status === "READY" && task.app_conversation_id) {
        return task.app_conversation_id;
      }
      if (task.status === "ERROR") {
        throw new Error(task.error ?? "OpenHands start task failed");
      }
      await sleep(5000);
    }
    throw new Error("Timed out waiting for OpenHands conversation");
  }

  async getConversation(conversationId: string): Promise<AppConversation> {
    const res = await fetch(
      `${this.env.openhandsBaseUrl}/api/v1/app-conversations/${conversationId}`,
      { headers: this.headers() },
    );
    if (!res.ok) {
      throw new Error(`OpenHands get conversation failed (${res.status}): ${await res.text()}`);
    }
    return (await res.json()) as AppConversation;
  }

  async sendMessage(conversationId: string, message: string): Promise<void> {
    const res = await fetch(
      `${this.env.openhandsBaseUrl}/api/v1/app-conversations/${conversationId}/actions/send-message`,
      {
        method: "POST",
        headers: this.headers(),
        body: JSON.stringify({
          message: { content: [{ type: "text", text: message }] },
        }),
      },
    );
    if (!res.ok) {
      throw new Error(`OpenHands send-message failed (${res.status}): ${await res.text()}`);
    }
  }

  async getAccessUrls(conversationId: string): Promise<ExposedUrl[]> {
    const conv = await this.getConversation(conversationId);
    const urls = [...(conv.exposed_urls ?? [])];

    if (conv.sandbox_id) {
      try {
        const res = await fetch(
          `${this.env.openhandsBaseUrl}/api/v1/sandboxes/${conv.sandbox_id}`,
          { headers: this.headers() },
        );
        if (res.ok) {
          const sandbox = (await res.json()) as SandboxRecord;
          for (const u of sandbox.exposed_urls ?? []) {
            if (!urls.some((x) => x.url === u.url)) urls.push(u);
          }
        }
      } catch {
        // sandbox endpoint may differ by version — conversation URLs are enough
      }
    }

    return urls;
  }

  conversationPublicUrl(conversationId: string): string {
    return `${this.env.openhandsPublicUrl}/conversations/${conversationId}`;
  }
}

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
