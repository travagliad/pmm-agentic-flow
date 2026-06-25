import type { Env } from "./config.js";

export type FbArtifacts = {
  submodulesPr: number;
  serverImage: string;
  clientImage: string;
  watchtowerImage?: string;
  clientTarballUrl?: string;
};

const SERVER_RE = /Server docker:\s*(\S+)/i;
const CLIENT_RE = /Client docker:\s*(\S+)/i;
const WATCHTOWER_RE = /Watchtower docker:\s*(\S+)/i;
const TARBALL_RE = /Client tarball:\s*(\S+)/i;

export class FbResolver {
  constructor(
    private readonly env: Env,
    private readonly submodulesRepo = "Percona-Lab/pmm-submodules",
  ) {}

  async resolveForTicket(ticketKey: string): Promise<FbArtifacts | undefined> {
    const pr = await this.findOpenSubmodulesPr(ticketKey);
    if (!pr) return undefined;
    return this.parseFromPrComments(pr);
  }

  async parseFromPrComments(prNumber: number): Promise<FbArtifacts | undefined> {
    const comments = await this.fetchPrComments(prNumber);
    for (const body of comments) {
      const parsed = this.parseJnkComment(body);
      if (parsed) return { ...parsed, submodulesPr: prNumber };
    }
    return undefined;
  }

  parseJnkComment(body: string): Omit<FbArtifacts, "submodulesPr"> | undefined {
    const server = body.match(SERVER_RE)?.[1];
    const client = body.match(CLIENT_RE)?.[1];
    if (!server || !client) return undefined;
    return {
      serverImage: server.trim(),
      clientImage: client.trim(),
      watchtowerImage: body.match(WATCHTOWER_RE)?.[1]?.trim(),
      clientTarballUrl: body.match(TARBALL_RE)?.[1]?.trim(),
    };
  }

  private async findOpenSubmodulesPr(ticketKey: string): Promise<number | undefined> {
    const q = encodeURIComponent(
      `repo:${this.submodulesRepo} is:pr is:open ${ticketKey} in:title`,
    );
    const res = await fetch(`https://api.github.com/search/issues?q=${q}&per_page=5`, {
      headers: this.githubHeaders(),
    });
    if (!res.ok) {
      throw new Error(`GitHub search failed (${res.status}): ${await res.text()}`);
    }
    const data = (await res.json()) as { items: Array<{ number: number; title: string }> };
    const match = data.items.find((i) =>
      i.title.toUpperCase().includes(ticketKey.toUpperCase()),
    );
    return match?.number;
  }

  private async fetchPrComments(prNumber: number): Promise<string[]> {
    const res = await fetch(
      `https://api.github.com/repos/${this.submodulesRepo}/issues/${prNumber}/comments?per_page=100`,
      { headers: this.githubHeaders() },
    );
    if (!res.ok) {
      throw new Error(`GitHub comments failed (${res.status}): ${await res.text()}`);
    }
    const comments = (await res.json()) as Array<{ user?: { login?: string }; body?: string }>;
    return comments
      .filter((c) => c.user?.login?.toLowerCase() === "jnkpercona")
      .map((c) => c.body ?? "");
  }

  private githubHeaders(): Record<string, string> {
    return {
      Authorization: `Bearer ${this.env.githubToken}`,
      Accept: "application/vnd.github+json",
      "X-GitHub-Api-Version": "2022-11-28",
    };
  }
}
