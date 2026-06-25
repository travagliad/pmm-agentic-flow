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

export type CanvasEndpoint = {
  baseUrl: string;
  publicUrl: string;
};

type ConversationInfo = {
  id: string;
  execution_status?: { status?: string };
};

export class OpenHandsClient {
  constructor(
    private readonly env: Env,
    private readonly endpoint?: CanvasEndpoint,
  ) {}

  private get baseUrl(): string {
    return this.endpoint?.baseUrl ?? this.env.agentCanvasBaseUrl;
  }

  private get publicUrl(): string {
    return this.endpoint?.publicUrl ?? this.env.agentCanvasPublicUrl;
  }

  private headers(json = true): Record<string, string> {
    const h: Record<string, string> = {
      "X-Session-API-Key": this.env.agentCanvasApiKey,
    };
    if (json) h["Content-Type"] = "application/json";
    return h;
  }

  private workspaceDir(repository: string): string {
    const name = repository.includes("/") ? repository.split("/").pop()! : repository;
    return `/projects/${name}`;
  }

  private async apiFetch(url: string, init?: RequestInit): Promise<Response> {
    try {
      return await fetch(url, init);
    } catch (err) {
      const detail = err instanceof Error ? err.message : String(err);
      const cause =
        err instanceof Error && err.cause instanceof Error ? ` — ${err.cause.message}` : "";
      throw new Error(`OpenHands request failed: ${detail}${cause} (${url})`);
    }
  }

  private useAcp(): boolean {
    return Boolean(this.env.cursorApiKey || this.env.githubCopilotToken);
  }

  private acpCommand(): string[] {
    if (this.env.cursorApiKey) return ["/usr/local/bin/agent", "acp"];
    return ["/usr/local/bin/copilot", "acp"];
  }

  private conversationSecrets(): Record<string, { kind: string; value: string }> | undefined {
    if (this.env.cursorApiKey) {
      return { CURSOR_API_KEY: { kind: "StaticSecret", value: this.env.cursorApiKey } };
    }
    const token = this.env.githubCopilotToken ?? this.env.githubToken;
    if (token) return { GITHUB_TOKEN: { kind: "StaticSecret", value: token } };
    return undefined;
  }

  async startConversation(params: {
    message: string;
    repository: string;
    branch?: string;
  }): Promise<StartTask> {
    const workingDir = this.workspaceDir(params.repository);
    const secrets = this.conversationSecrets();
    if (!this.useAcp()) {
      throw new Error(
        "CURSOR_API_KEY or GITHUB_COPILOT_TOKEN required — configure on control plane /etc/pmm-agentic-flow/env",
      );
    }

    const body = {
      agent: {
        kind: "ACPAgent",
        acp_command: this.acpCommand(),
        ...(this.env.cursorApiKey
          ? { acp_env: { CURSOR_API_KEY: this.env.cursorApiKey } }
          : {}),
      },
      workspace: {
        working_dir: workingDir,
        kind: "LocalWorkspace",
      },
      initial_message: {
        content: [{ text: params.message }],
        run: true,
      },
      ...(secrets ? { secrets } : {}),
    };

    const res = await this.apiFetch(`${this.baseUrl}/api/conversations`, {
      method: "POST",
      headers: this.headers(),
      body: JSON.stringify(body),
    });

    if (!res.ok) {
      throw new Error(`OpenHands start failed (${res.status}): ${await res.text()}`);
    }

    const created = (await res.json()) as ConversationInfo;
    await this.runConversation(created.id);

    return {
      id: created.id,
      status: "READY",
      app_conversation_id: created.id,
    };
  }

  async waitForConversation(startTaskId: string, _timeoutMs = 600_000): Promise<string> {
    const res = await this.apiFetch(`${this.baseUrl}/api/conversations/${startTaskId}`, {
      headers: this.headers(false),
    });
    if (!res.ok) {
      throw new Error(`OpenHands get conversation failed (${res.status}): ${await res.text()}`);
    }
    const conv = (await res.json()) as ConversationInfo;
    return conv.id;
  }

  async getConversation(conversationId: string): Promise<AppConversation> {
    const res = await this.apiFetch(`${this.baseUrl}/api/conversations/${conversationId}`, {
      headers: this.headers(false),
    });
    if (!res.ok) {
      throw new Error(`OpenHands get conversation failed (${res.status}): ${await res.text()}`);
    }
    const conv = (await res.json()) as ConversationInfo;
    return {
      id: conv.id,
      status: conv.execution_status?.status ?? "unknown",
    };
  }

  async sendMessage(conversationId: string, message: string): Promise<void> {
    const res = await this.apiFetch(`${this.baseUrl}/api/conversations/${conversationId}/events`, {
      method: "POST",
      headers: this.headers(),
      body: JSON.stringify({
        content: [{ text: message }],
        run: true,
      }),
    });
    if (!res.ok) {
      throw new Error(`OpenHands send-message failed (${res.status}): ${await res.text()}`);
    }
  }

  async getAccessUrls(conversationId: string): Promise<ExposedUrl[]> {
    const urls: ExposedUrl[] = [];
    urls.push({
      name: "conversation",
      url: this.conversationPublicUrl(conversationId),
    });

    try {
      const res = await this.apiFetch(
        `${this.baseUrl}/api/vscode/url?workspace_dir=${encodeURIComponent("/projects/pmm")}`,
        { headers: this.headers(false) },
      );
      if (res.ok) {
        const data = (await res.json()) as { url?: string | null };
        if (data.url) {
          urls.push({ name: "VS Code", url: data.url });
        }
      }
    } catch {
      // optional
    }

    return urls;
  }

  conversationPublicUrl(conversationId: string): string {
    return `${this.publicUrl}/conversations/${conversationId}`;
  }

  private async runConversation(conversationId: string): Promise<void> {
    const res = await this.apiFetch(`${this.baseUrl}/api/conversations/${conversationId}/run`, {
      method: "POST",
      headers: this.headers(false),
    });
    if (!res.ok && res.status !== 409) {
      throw new Error(`OpenHands run failed (${res.status}): ${await res.text()}`);
    }
  }
}
