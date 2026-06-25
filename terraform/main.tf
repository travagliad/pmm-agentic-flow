terraform {
  required_version = ">= 1.5.0"
  required_providers {
    linode = {
      source  = "linode/linode"
      version = "~> 2.30"
    }
  }
}

provider "linode" {
  token = var.linode_token
}

resource "linode_instance" "loop_host" {
  label            = var.label
  region           = var.region
  type             = var.instance_type
  image            = "linode/ubuntu24.04"
  root_pass        = var.root_password
  tags             = concat(["agentic-flow"], var.tags)
  watchdog_enabled = true

  metadata {
    user_data = base64encode(templatefile("${path.module}/cloud-init.yaml.tpl", {
      bootstrap_repo_url     = var.bootstrap_repo_url
      github_token           = var.github_token
      agent_canvas_api_key   = coalesce(var.agent_canvas_api_key, var.openhands_api_key)
      agent_canvas_secret_key = var.agent_canvas_secret_key
      agent_canvas_version   = var.agent_canvas_version
      orchestrator_api_key   = var.orchestrator_api_key
      jira_base_url          = var.jira_base_url
      jira_email             = var.jira_email
      jira_api_token         = var.jira_api_token
      jira_webhook_secret    = var.jira_webhook_secret
      linode_token           = var.linode_token
      worker_root_password   = var.worker_root_password
      worker_linode_type     = var.worker_linode_type
      worker_linode_region   = var.worker_linode_region
    }))
  }
}

resource "linode_firewall" "loop" {
  label = "${var.label}-fw"

  inbound {
    label    = "allow-ssh"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "22"
    ipv4     = var.admin_cidrs
    ipv6     = var.admin_cidrs_v6
  }

  inbound {
    label    = "allow-agent-canvas"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "8000"
    ipv4     = ["0.0.0.0/0"]
  }

  inbound {
    label    = "allow-orchestrator"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "8080"
    ipv4     = ["0.0.0.0/0"]
  }

  inbound_policy  = "DROP"
  outbound_policy = "ACCEPT"
  linodes         = [linode_instance.loop_host.id]
}

output "instance_id" {
  value = linode_instance.loop_host.id
}

output "public_ip" {
  value = linode_instance.loop_host.ip_address
}

output "ssh_command" {
  value = "ssh root@${linode_instance.loop_host.ip_address}"
}

output "app_url" {
  value       = "http://${linode_instance.loop_host.ip_address}:8000/"
  description = "Agent Canvas UI (direct HTTP, no reverse proxy)."
}

output "jira_webhook_url" {
  value = "http://${linode_instance.loop_host.ip_address}:8080/hooks/jira"
}

output "next_steps" {
  value = <<-EOT
    1. Wait ~5 min for cloud-init
    2. SSH: ssh root@${linode_instance.loop_host.ip_address}
    3. Open: http://${linode_instance.loop_host.ip_address}:8000/
    4. Jira webhook: http://${linode_instance.loop_host.ip_address}:8080/hooks/jira
    5. API key: grep AGENT_CANVAS_API_KEY /etc/pmm-agentic-flow/env
  EOT
}

output "openhands_url" {
  value       = "http://${linode_instance.loop_host.ip_address}:8000/"
  description = "Deprecated alias for app_url."
}
