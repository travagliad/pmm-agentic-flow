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
      AGENT_CANVAS_PUBLIC_URL=${public_url_placeholder}
      AGENT_CANVAS_VERSION=${agent_canvas_version}
      AGENT_CANVAS_API_KEY=${agent_canvas_api_key}
      LOCAL_BACKEND_API_KEY=${agent_canvas_api_key}
      AGENT_CANVAS_SECRET_KEY=${agent_canvas_secret_key}
      OH_SECRET_KEY=${agent_canvas_secret_key}
      ORCHESTRATOR_API_KEY=${api_secret}
      ORCHESTRATOR_PORT=8080
      AGENT_CANVAS_BASE_URL=http://127.0.0.1:8000
      STACK_CONFIG_PATH=/opt/pmm-agentic-flow/src/config/stack.yaml
      JIRA_WORKFLOW_PATH=/opt/pmm-agentic-flow/src/config/jira-workflow.yaml
      DATA_DIR=/var/lib/pmm-agentic-flow/orchestrator
      BOOTSTRAP_REPO_URL=${bootstrap_repo_url}
      BOOTSTRAP_DEST=/opt/pmm-agentic-flow/src
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
      JIRA_WEBHOOK_SECRET=${api_secret}
      CURSOR_API_KEY=${cursor_api_key}
      NGROK_AUTHTOKEN=${ngrok_authtoken}
      NGROK_DOMAIN=${ngrok_domain}
      EXPOSE_PORTS_DIRECTLY=${expose_ports_directly}

  - path: /opt/pmm-agentic-flow/bootstrap.sh
    permissions: "0755"
    content: |
      #!/usr/bin/env bash
      set -euo pipefail
      DEST=/opt/pmm-agentic-flow/src
      if [ ! -f "$DEST/deploy/bootstrap-host.sh" ]; then
        echo "ERROR: repo not cloned yet" >&2
        exit 1
      fi
      bash "$DEST/deploy/bootstrap-host.sh" 2>&1 | tee -a /var/log/pmm-agentic-flow-bootstrap.log
      exit "$${PIPESTATUS[0]}"

runcmd:
  - ufw allow OpenSSH
%{ if expose_ports_directly ~}
  - ufw allow 8000/tcp
  - ufw allow 8080/tcp
%{ endif ~}
  - ufw --force enable
  - mkdir -p /opt/pmm-agentic-flow /var/lib/pmm-agentic-flow/orchestrator
  - git clone ${bootstrap_repo_url} /opt/pmm-agentic-flow/src
  - /opt/pmm-agentic-flow/bootstrap.sh
