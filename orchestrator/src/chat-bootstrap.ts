import type { Env } from "./config.js";
import type { TicketRecord } from "./ticket-store.js";

export function ticketChatUrl(env: Env, ticketKey: string): string {
  const base = env.agentCanvasPublicUrl.replace(/\/$/, "");
  return `${base}/tickets/${ticketKey}/chat`;
}

export function chatBootstrapHtml(ticket: TicketRecord, env: Env): string {
  const ticketKey = ticket.ticketKey;
  const conversationId = ticket.conversationId;
  const publicBase = env.agentCanvasPublicUrl.replace(/\/$/, "");

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
  <title>${escapeHtml(ticketKey)} — starting chat</title>
  <style>
    body { font-family: system-ui, sans-serif; max-width: 40rem; margin: 2rem auto; line-height: 1.5; }
    .log { color: #555; font-size: 0.9rem; border-left: 3px solid #ccc; padding-left: 0.75rem; }
  </style>
</head>
<body>
  <h1>${escapeHtml(ticketKey)}</h1>
  <p>Starting conversation on the central chat. This page refreshes automatically.</p>
  ${logLine}
  <script>setTimeout(function() { location.reload(); }, ${pollMs});</script>
</body>
</html>`;
  }

  const conversationUrl = `${publicBase}/conversations/${conversationId}`;
  const apiKey = env.agentCanvasApiKey;

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <title>${escapeHtml(ticketKey)} — opening chat</title>
  <style>
    body { font-family: system-ui, sans-serif; max-width: 40rem; margin: 3rem auto; padding: 0 1rem; color: #1a1a1a; }
    a { color: #0b5fff; }
  </style>
</head>
<body>
  <p>Opening <strong>${escapeHtml(ticketKey)}</strong> in the central chat…</p>
  <p><a href="${conversationUrl}">Continue</a> if you are not redirected.</p>
  <script>
    (function () {
      var configKey = "openhands-agent-server-config";
      var apiKey = ${JSON.stringify(apiKey)};
      try {
        var cfg = JSON.parse(localStorage.getItem(configKey) || "{}");
        if (!cfg.sessionApiKey && apiKey) {
          cfg.sessionApiKey = apiKey;
          localStorage.setItem(configKey, JSON.stringify(cfg));
        }
      } catch (e) {}
      location.replace(${JSON.stringify(conversationUrl)});
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
