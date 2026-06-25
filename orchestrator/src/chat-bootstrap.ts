import type { Env } from "./config.js";
import type { TicketRecord } from "./ticket-store.js";

export function sandboxBackendId(ticketKey: string): string {
  return `sandbox-${ticketKey.toLowerCase()}`;
}

export function sandboxBackendHost(publicBase: string, ticketKey: string): string {
  const base = publicBase.replace(/\/$/, "");
  return `${base}/sandbox/${ticketKey}`;
}

export function ticketChatUrl(env: Env, ticketKey: string): string {
  const base = env.agentCanvasPublicUrl.replace(/\/$/, "");
  return `${base}/tickets/${ticketKey}/chat`;
}

export function chatBootstrapHtml(ticket: TicketRecord, env: Env): string {
  const ticketKey = ticket.ticketKey;
  const conversationId = ticket.conversationId;
  const publicBase = env.agentCanvasPublicUrl.replace(/\/$/, "");
  const backendId = sandboxBackendId(ticketKey);
  const backendHost = sandboxBackendHost(publicBase, ticketKey);

  if (!conversationId) {
    const latestLog = ticket.logs.length > 0 ? ticket.logs[ticket.logs.length - 1] : "";
    const logLine = latestLog
      ? `<p class="log">${escapeHtml(latestLog)}</p>`
      : '<p class="log">Waiting for orchestrator…</p>';
    const pollMs = 12_000;

    return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta http-equiv="refresh" content="12">
  <title>${escapeHtml(ticketKey)} — provisioning</title>
  <style>
    body { font-family: system-ui, sans-serif; max-width: 40rem; margin: 2rem auto; line-height: 1.5; }
    .log { color: #555; font-size: 0.9rem; border-left: 3px solid #ccc; padding-left: 0.75rem; }
  </style>
</head>
<body>
  <h1>${escapeHtml(ticketKey)}</h1>
  <p>Provisioning sandbox runner and starting conversation. This page refreshes automatically.</p>
  ${logLine}
  <script>setTimeout(function() { location.reload(); }, ${pollMs});</script>
</body>
</html>`;
  }

  const conversationUrl = `${publicBase}/conversations/${conversationId}`;

  return `<!DOCTYPE html>
<html lang="en">
<head><meta charset="utf-8"><title>${ticketKey} chat</title></head>
<body><p>Opening chat…</p>
<script>
(function() {
  const backendId = ${JSON.stringify(backendId)};
  const backendHost = ${JSON.stringify(backendHost)};
  const backendName = ${JSON.stringify(ticketKey)};
  const conversationUrl = ${JSON.stringify(conversationUrl)};
  const publicBase = ${JSON.stringify(publicBase)};
  const configKey = "openhands-agent-server-config";
  const backendsKey = "openhands-backends";
  const activeKey = "openhands-active-backend";

  let apiKey = "";
  try {
    const cfg = JSON.parse(localStorage.getItem(configKey) || "{}");
    apiKey = cfg.sessionApiKey || "";
  } catch (_) {}

  if (!apiKey) {
    sessionStorage.setItem("pmm-chat-return", conversationUrl);
    sessionStorage.setItem("pmm-pending-backend", JSON.stringify({
      id: backendId,
      name: backendName,
      host: backendHost,
      kind: "local"
    }));
    location.replace(publicBase + "/");
    return;
  }

  let backends = [];
  try {
    backends = JSON.parse(localStorage.getItem(backendsKey) || "[]");
  } catch (_) {}

  const backend = { id: backendId, name: backendName, host: backendHost, apiKey: apiKey, kind: "local" };
  const idx = backends.findIndex(function(b) { return b.id === backendId; });
  if (idx >= 0) backends[idx] = backend;
  else backends.push(backend);

  localStorage.setItem(backendsKey, JSON.stringify(backends));
  const active = { backendId: backendId, orgId: null };
  localStorage.setItem(activeKey, JSON.stringify(active));
  sessionStorage.setItem(activeKey, JSON.stringify(active));
  location.replace(conversationUrl);
})();
</script>
</body>
</html>`;
}

function escapeHtml(text: string): string {
  return text
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}
