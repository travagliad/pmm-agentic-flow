# Cursor API (sem ACP no UI)

Agent Canvas **não** aceita `CURSOR_API_KEY` em **Settings → LLM** como Anthropic/OpenAI. A Cursor API é outro produto.

## Dois modos Cursor

| Modo | O que é | Chat no Canvas `:8000`? |
|------|---------|-------------------------|
| **ACP** (`agent acp`, npx wrappers) | JSON-RPC stdio → CLI Cursor | Sim (Manage Backends / Settings → Agent) |
| **Cloud Agents API** (`api.cursor.com/v1/agents`) | REST — agente na cloud num repo GitHub | **Não** — async, repo-based, via API/scripts |

Se não queres ACP no UI, o caminho é **Cloud Agents API** (orchestrator/scripts), não Settings → LLM.

## 1. Obter API key

1. https://cursor.com/dashboard  
2. **Settings** → **API Keys** → **New API Key**  
   (Cloud Agents: https://cursor.com/dashboard?tab=cloud-agents → My Settings → API keys)  
3. Copia a key (`crsr_...`) — só aparece uma vez

## 2. Guardar no servidor

Set `cursor_api_key` in `terraform/terraform.tfvars` — cloud-init writes `/etc/pmm-agentic-flow/env`.

## 3. Testar a key

```bash
source /etc/pmm-agentic-flow/env
curl -sS -u "${CURSOR_API_KEY}:" https://api.cursor.com/v1/me | jq .
```

## 4. Lançar um Cloud Agent (exemplo)

Substitui o repo pelo teu fork/branch PMM:

```bash
source .env
curl -sS -X POST https://api.cursor.com/v1/agents \
  -u "${CURSOR_API_KEY}:" \
  -H 'Content-Type: application/json' \
  -d '{
    "prompt": { "text": "List the top 3 files in this repo and summarize the README." },
    "model": { "id": "composer-2" },
    "repos": [
      { "url": "https://github.com/percona/pmm", "startingRef": "main" }
    ]
  }' | jq .
```

Resposta: `id` do agente. Estado:

```bash
curl -sS "https://api.cursor.com/v1/agents/<AGENT_ID>" \
  -u "${CURSOR_API_KEY}:" | jq .
```

Docs: [Cloud Agents API](https://cursor.com/docs/cloud-agent/api/endpoints)

## 5. O que isto **não** faz

- **Não** remove o aviso “LLM isn't set up” no Canvas — isso é o agente **local** OpenHands, que precisa de provider LiteLLM (Anthropic/OpenAI/…) **ou** ACP.
- **Não** substitui chat interativo no browser — Cloud Agents corre na infra Cursor, ligado ao GitHub.

## 6. Próximo passo no POC (orchestrator)

Para Jira **In Progress** → Cursor Cloud Agent em vez de conversa Canvas:

- orchestrator chama `POST /v1/agents` com repo + prompt do ticket  
- comenta link/status no Jira quando o agente termina  

Isso é integração no `orchestrator/` — pede se quiseres que implementemos.

## CLI headless (alternativa, ainda não é Canvas UI)

Mesma key, sem ACP no Manage Backends:

```bash
export CURSOR_API_KEY=crsr_...
agent -p "Explain this repo in one paragraph"
```

Precisa do CLI instalado automaticamente pelo entrypoint (`/usr/local/bin/agent`).
