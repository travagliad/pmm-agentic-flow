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
  const apiKey = env.agentCanvasApiKey;
  const sandboxHost = backendHost;

  return `<!DOCTYPE html>
<html lang="en">
<head><meta charset="utf-8"><title>${ticketKey} chat</title></head>
<body><p>Opening chat…</p>
<script>
(function() {
  const ticketKey = ${JSON.stringify(ticketKey)};
  const sandboxHost = ${JSON.stringify(sandboxHost)};
  const conversationUrl = ${JSON.stringify(conversationUrl)};
  const apiKey = ${JSON.stringify(apiKey)};
  const configKey = "openhands-agent-server-config";
  const backendsKey = "openhands-backends";
  const activeKey = "openhands-active-backend";
  const restoreKey = "pmm-sandbox-host-restore";

  try {
    const cfg = JSON.parse(localStorage.getItem(configKey) || "{}");
    if (!cfg.sessionApiKey) {
      cfg.sessionApiKey = apiKey;
      localStorage.setItem(configKey, JSON.stringify(cfg));
    }
  } catch (_) {}

  let backends = [];
  try {
    backends = JSON.parse(localStorage.getItem(backendsKey) || "[]");
  } catch (_) {}

  let active = null;
  try {
    active = JSON.parse(localStorage.getItem(activeKey) || sessionStorage.getItem(activeKey) || "null");
  } catch (_) {}

  let target = active && active.backendId
    ? backends.find(function(b) { return b.id === active.backendId; })
    : null;
  if (!target && backends.length > 0) target = backends[0];
  if (!target) {
    target = {
      id: "local",
      name: "Local",
      host: ${JSON.stringify(publicBase)},
      apiKey: apiKey,
      kind: "local",
    };
    backends.push(target);
  }

  try {
    const restore = JSON.parse(sessionStorage.getItem(restoreKey) || "{}");
    if (!restore[target.id]) {
      restore[target.id] = { host: target.host, name: target.name, ticketKey: ticketKey };
      sessionStorage.setItem(restoreKey, JSON.stringify(restore));
    }
  } catch (_) {}

  target.host = sandboxHost;
  target.apiKey = apiKey;
  target.name = ticketKey + " (sandbox)";
  target.kind = "local";

  const idx = backends.findIndex(function(b) { return b.id === target.id; });
  if (idx >= 0) backends[idx] = target;
  else backends.push(target);

  localStorage.setItem(backendsKey, JSON.stringify(backends));
  const activeState = { backendId: target.id, orgId: null };
  localStorage.setItem(activeKey, JSON.stringify(activeState));
  sessionStorage.setItem(activeKey, JSON.stringify(activeState));
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
