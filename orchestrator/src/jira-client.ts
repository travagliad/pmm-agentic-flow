import type { Env } from "./config.js";

export class JiraClient {
  constructor(private readonly env: Env) {}

  get enabled(): boolean {
    return Boolean(this.env.jiraBaseUrl && this.env.jiraEmail && this.env.jiraApiToken);
  }

  async addComment(issueKey: string, body: string): Promise<void> {
    if (!this.enabled) {
      console.log(`[jira:disabled] ${issueKey}: ${body.slice(0, 200)}…`);
      return;
    }

    const auth = Buffer.from(`${this.env.jiraEmail}:${this.env.jiraApiToken}`).toString("base64");
    const res = await fetch(`${this.env.jiraBaseUrl}/rest/api/3/issue/${issueKey}/comment`, {
      method: "POST",
      headers: {
        Authorization: `Basic ${auth}`,
        "Content-Type": "application/json",
        Accept: "application/json",
      },
      body: JSON.stringify({
        body: {
          type: "doc",
          version: 1,
          content: [
            {
              type: "paragraph",
              content: [{ type: "text", text: body }],
            },
          ],
        },
      }),
    });

    if (!res.ok) {
      throw new Error(`Jira comment failed (${res.status}): ${await res.text()}`);
    }
  }
}
