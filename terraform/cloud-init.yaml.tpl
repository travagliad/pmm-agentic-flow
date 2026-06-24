#cloud-config
package_update: true
package_upgrade: true

packages:
  - ca-certificates
  - curl
  - git
  - jq
  - ufw
  - fail2ban
  - unattended-upgrades

write_files:
  - path: /etc/pmm-agentic-flow/env
    permissions: "0600"
    content: |
      LOOP_DOMAIN=${domain}
      ACME_EMAIL=${acme_email}
      AGENT_CANVAS_PUBLIC_URL=https://${domain}
      AGENT_CANVAS_VERSION=${agent_canvas_version}
      AGENT_CANVAS_API_KEY=${agent_canvas_api_key}
      AGENT_CANVAS_SECRET_KEY=${agent_canvas_secret_key}
      AGENT_CANVAS_UID=1000
      OPENHANDS_PUBLIC_URL=https://${domain}
      OPENHANDS_API_KEY=${agent_canvas_api_key}
      GITHUB_TOKEN=${github_token}
      GITHUB_COPILOT_TOKEN=${github_copilot_token}
      LITELLM_MASTER_KEY=${litellm_master_key}
      LITELLM_MODEL=${litellm_model}
      ORCHESTRATOR_API_KEY=${orchestrator_api_key}
      ORCHESTRATOR_PORT=8080
      SANDBOX_TTL_HOURS=72
      MAX_AGENT_RETRIES=2
      MAX_BUILD_RETRIES=5
      JIRA_BASE_URL=${jira_base_url}
      JIRA_EMAIL=${jira_email}
      JIRA_API_TOKEN=${jira_api_token}
      JIRA_WEBHOOK_SECRET=${jira_webhook_secret}
      COPILOT_EDITOR_VERSION=vscode/1.96.0
      COPILOT_INTEGRATION_ID=vscode-chat

  - path: /opt/pmm-agentic-flow/bootstrap.sh
    permissions: "0755"
    content: |
      #!/usr/bin/env bash
      set -euo pipefail
      REPO="${bootstrap_repo_url}"
      DEST=/opt/pmm-agentic-flow/src
      echo "Cloning $REPO → $DEST"
      if [ ! -d "$DEST/.git" ]; then
        git clone "$REPO" "$DEST"
      else
        git -C "$DEST" pull --ff-only
      fi
      cp /etc/pmm-agentic-flow/env "$DEST/.env"
      cd "$DEST/deploy"
      docker compose --env-file "$DEST/.env" pull
      docker compose --env-file "$DEST/.env" up -d --build
      echo "Stack deployed. Open https://${domain}/ when DNS + TLS are ready."

runcmd:
  - ufw allow OpenSSH
  - ufw allow 80/tcp
  - ufw allow 443/tcp
  - ufw --force enable
  - curl -fsSL https://get.docker.com | sh
  - usermod -aG docker root
  - systemctl enable docker
  - systemctl start docker
  - mkdir -p /opt/pmm-agentic-flow
  - |
    cat >/etc/systemd/system/pmm-agentic-flow.service <<'UNIT'
    [Unit]
    Description=PMM Agentic Flow stack
    After=docker.service
    Requires=docker.service

    [Service]
    Type=oneshot
    RemainAfterExit=yes
    WorkingDirectory=/opt/pmm-agentic-flow/src/deploy
    ExecStart=/usr/bin/docker compose --env-file /opt/pmm-agentic-flow/src/.env up -d
    ExecStop=/usr/bin/docker compose --env-file /opt/pmm-agentic-flow/src/.env down

    [Install]
    WantedBy=multi-user.target
    UNIT
  - /opt/pmm-agentic-flow/bootstrap.sh 2>&1 | tee /var/log/pmm-agentic-flow-bootstrap.log
