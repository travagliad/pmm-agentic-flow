# LLM backends via ACP (Agent Client Protocol)

Agent Canvas supports external agent backends over **ACP** — JSON-RPC 2.0 on stdio, same pattern for Cursor and GitHub Copilot.

No LiteLLM container in this stack.

## Cursor

```bash
# On the Linode (or your dev machine for testing)
agent login
# or: export CURSOR_API_KEY=...

agent acp   # stdio JSON-RPC server
```

In **Agent Canvas → Manage Backends**, add an ACP backend pointing at the `agent` binary with args `["acp"]`. Auth via `cursor_login` or pre-export `CURSOR_API_KEY`.

Docs: [Cursor CLI ACP](https://cursor.com/docs/cli/acp)

## GitHub Copilot

Copilot CLI also supports ACP in recent versions — same wiring:

```bash
copilot login   # or GH token
copilot acp     # if available in your copilot CLI version
```

Configure in Manage Backends the same way: command + `acp` arg, stdio transport.

If your Copilot build lacks `acp` subcommand yet, use Anthropic/OpenAI API keys directly in Canvas Settings until Copilot ACP is available.

## Team note

Each developer's `agent login` / Copilot login is personal. For a shared VM used by a team, use a **service API key** (Cursor org key, Copilot org subscription) stored in `/etc/pmm-agentic-flow/env` and injected into the backend process — not individual laptop logins.
