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
      AGENT_CANVAS_PUBLIC_URL=http://__PUBLIC_IP__:8000
      AGENT_CANVAS_VERSION=${agent_canvas_version}
      AGENT_CANVAS_API_KEY=${agent_canvas_api_key}
      AGENT_CANVAS_SECRET_KEY=${agent_canvas_secret_key}
      AGENT_CANVAS_UID=1000
      ORCHESTRATOR_API_KEY=${orchestrator_api_key}
      ORCHESTRATOR_PORT=8080
      GITHUB_TOKEN=${github_token}
      GITHUB_COPILOT_TOKEN=${github_copilot_token}
      LINODE_TOKEN=${linode_token}
      WORKER_ROOT_PASSWORD=${worker_root_password}
      SANDBOX_TTL_HOURS=72
      MAX_AGENT_RETRIES=2
      MAX_BUILD_RETRIES=5
      JIRA_BASE_URL=${jira_base_url}
      JIRA_EMAIL=${jira_email}
      JIRA_API_TOKEN=${jira_api_token}
      JIRA_WEBHOOK_SECRET=${jira_webhook_secret}
      CURSOR_API_KEY=${cursor_api_key}

  - path: /opt/pmm-agentic-flow/bootstrap.sh
    permissions: "0755"
    content: |
      #!/usr/bin/env bash
      set -euo pipefail
      REPO="${bootstrap_repo_url}"
      DEST=/opt/pmm-agentic-flow/src
      ENV_FILE=/etc/pmm-agentic-flow/env
      PUBLIC_IP="$(curl -4 -fsSL https://ifconfig.me/ip 2>/dev/null || curl -4 -fsSL https://ipv4.icanhazip.com)"
      echo "Public IPv4: $PUBLIC_IP"
      sed -i "s|__PUBLIC_IP__|$PUBLIC_IP|g" "$ENV_FILE"
      echo "Cloning $REPO -> $DEST"
      if [ ! -d "$DEST/.git" ]; then
        git clone "$REPO" "$DEST"
      else
        git -C "$DEST" pull --ff-only
      fi
      for legacy in caddy loop-caddy loop-litellm loop-openhands loop-orchestrator; do
        docker rm -f "$legacy" 2>/dev/null || true
      done
      mkdir -p /etc/docker
      if ! grep -q '"ipv6"' /etc/docker/daemon.json 2>/dev/null; then
        printf '%s\n' '{ "ipv6": false }' > /etc/docker/daemon.json
        systemctl restart docker
        sleep 3
      fi
      cd "$DEST/deploy"
      pull_ok=0
      for attempt in 1 2 3 4 5; do
        if docker compose --env-file "$ENV_FILE" pull; then
          pull_ok=1
          break
        fi
        echo "docker compose pull failed (attempt $attempt/5), retry in 30s..."
        sleep 30
      done
      if [ "$pull_ok" -ne 1 ]; then
        echo "ERROR: docker compose pull failed after 5 attempts" >&2
        exit 1
      fi
      docker compose --env-file "$ENV_FILE" run --rm agent-canvas-init
      docker compose --env-file "$ENV_FILE" up -d --build --remove-orphans
      echo "Stack deployed. Open http://$PUBLIC_IP:8000/"

runcmd:
  - ufw allow OpenSSH
  - ufw allow 8000/tcp
  - ufw allow 8080/tcp
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
    ExecStart=/usr/bin/docker compose --env-file /etc/pmm-agentic-flow/env up -d
    ExecStop=/usr/bin/docker compose --env-file /etc/pmm-agentic-flow/env down

    [Install]
    WantedBy=multi-user.target
    UNIT
  - /opt/pmm-agentic-flow/bootstrap.sh 2>&1 | tee /var/log/pmm-agentic-flow-bootstrap.log
