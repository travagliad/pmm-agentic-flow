# Architecture FAQ

Answers aligned with [OpenHands Agent Canvas VM install](https://docs.openhands.dev/openhands/usage/agent-canvas/backend-setup/vm).

## 1. systemd não está na documentação deles — estou errado?

Não estás errado. A doc OpenHands usa **`tmux`** para manter o `agent-canvas` a correr depois de fechares o SSH. Nós usamos **systemd** no mesmo papel: processo always-on após cloud-init, sem sessão SSH aberta.

É o equivalente Linux/server do que eles sugerem com tmux. O comando é o mesmo: `agent-canvas --public`.

## 2. Docker no host?

**Não** — no modelo atual não instalamos Docker nem no control plane nem nos runners.

Cada ticket recebe uma **VM Linode dedicada**. O Agent Canvas corre em processo no host (`agent-canvas --public`). O isolamento é a própria VM, não containers Docker por conversa.

## 3. O orchestrator não reinventa a roda?

**OpenHands / Agent Canvas** faz:

- UI + agent server
- Conversas, sandboxes, ACP, skills, secrets no Canvas
- Automations (genéricas)

**O nosso orchestrator** faz o que o Canvas **não** faz:

- Webhook Jira → transições PMM (`In Progress`, `In QA`, …)
- Resolver imagens FB em `pmm-submodules`
- Provisionar **um runner Linode por ticket** (`runner_per_chat`)
- Comentários Jira com link do Canvas no runner
- Prompts `/opsx:*` e `/loop:qa` por fase

Não é substituto do Canvas — é **camada PMM** por cima. No futuro parte disto pode migrar para Canvas Automations, mas Jira + Linode + FB continuam custom.

## 4. ngrok + domínio custom

Com `ngrok_authtoken` + `ngrok_domain` no `terraform.tfvars`:

- Terraform **não abre** :8000/:8080 na internet
- nginx local em `127.0.0.1:8787` junta Canvas + orchestrator
- `ngrok http 8787 --url=<teu-domínio>` expõe HTTPS estável
- Jira webhook: `https://<domínio>/hooks/jira`
- Canvas: `https://<domínio>/`

Domínio estático gratuito: [ngrok dashboard → Domains](https://dashboard.ngrok.com/domains).

## 5. Instalamos como eles ensinam?

Sim — `deploy/install-runner.sh` segue os passos oficiais VM:

```bash
apt-get install -y ca-certificates curl gnupg git
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt-get install -y nodejs
curl -LsSf https://astral.sh/uv/install.sh | sh
npm install -g @openhands/agent-canvas
```

Extra nosso: Cursor CLI (ACP), cloud-init via Linode API para runners efémeros.

Control plane: `deploy/install-control-plane.sh` — Node + nginx + ngrok, sem Canvas.

## 6. Firewall como na doc deles

Com **ngrok** (default recomendado):

| Porta | Linode firewall |
|-------|-----------------|
| 22 SSH | só `admin_cidrs` (o teu IP) |
| 8080 | **fechada** (ngrok) ou aberta com `expose_ports_directly` |

## 7. Legado

Compose, entrypoint Docker e scripts de recover foram **removidos**. Greenfield.

## 8. Spinup só com Terraform

`terraform apply` → cloud-init → `git clone` → `bootstrap-host.sh` → systemd + ngrok opcional. **Zero passos manuais no Linode.**

## 9. Trocar de Linode sem perder chats?

**Possível, não automático.**

| O quê | Onde vive |
|-------|-----------|
| Conversas, settings Canvas | `~/.openhands` (symlink → volume) |
| Tickets orchestrator | `/var/lib/pmm-agentic-flow/orchestrator` (symlink → volume) |
| Domínio ngrok | ngrok cloud — reconfiguras no Linode novo com o mesmo token/domínio |

Terraform cria `data_volume_size` GB block storage. Para migrar:

1. `terraform destroy` **sem** destruir o volume (ou detach manual)
2. Novo `terraform apply` + attach do mesmo volume (`data_volume_id` output)
3. Mesmo `ngrok_domain` no tfvars

Sem volume: apagar Linode = perder chats.

## 10. O que os utilizadores precisam?

| Quem | Precisa de |
|------|------------|
| **Dev / QA / PO** | Browser → URL pública (ngrok). Uma vez: `LOCAL_BACKEND_API_KEY` (o valor de `agent_canvas_api_key`). Configurar ACP (`/usr/local/bin/agent acp`) se usarem Cursor. **Sem instalar nada.** |
| **Operador** | `terraform apply`, tfvars, Jira webhook URL |
| **Opcional power user** | `agent-canvas --frontend-only` no laptop apontando ao backend remoto ([doc backend-only](https://docs.openhands.dev/openhands/usage/agent-canvas/backend-setup/vm)) |

Utilizadores finais **não** instalam Node, Docker nem CLI — só o web app.
