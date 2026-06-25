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
      AGENT_CANVAS_PUBLIC_URL=https://__PUBLIC_IP__
      AGENT_CANVAS_VERSION=${agent_canvas_version}
      AGENT_CANVAS_API_KEY=${agent_canvas_api_key}
      AGENT_CANVAS_SECRET_KEY=${agent_canvas_secret_key}
      AGENT_CANVAS_UID=1000
      ORCHESTRATOR_API_KEY=${orchestrator_api_key}
      ORCHESTRATOR_PORT=8080
      GITHUB_TOKEN=${github_token}
      LINODE_TOKEN=${linode_token}
      WORKER_ROOT_PASSWORD=${worker_root_password}
      WORKER_LINODE_TYPE=${worker_linode_type}
      WORKER_LINODE_REGION=${worker_linode_region}
      SANDBOX_TTL_HOURS=72
      MAX_AGENT_RETRIES=2
      MAX_BUILD_RETRIES=5
      JIRA_BASE_URL=${jira_base_url}
      JIRA_EMAIL=${jira_email}
      JIRA_API_TOKEN=${jira_api_token}
      JIRA_WEBHOOK_SECRET=${jira_webhook_secret}

  - path: /opt/pmm-agentic-flow/bootstrap.sh
    permissions: "0755"
    content: |
      #!/usr/bin/env bash
      set -euo pipefail
      REPO="${bootstrap_repo_url}"
      DEST=/opt/pmm-agentic-flow/src
      PUBLIC_IP="$(curl -fsSL https://ifconfig.me/ip 2>/dev/null || hostname -I | awk '{print $1}')"
      echo "Public IP: $PUBLIC_IP"
      sed -i "s|__PUBLIC_IP__|$PUBLIC_IP|g" /etc/pmm-agentic-flow/env
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
      echo "Stack deployed. Open https://$PUBLIC_IP/ (accept self-signed cert on first visit)."

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
    Description=Agentic flow stack
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
