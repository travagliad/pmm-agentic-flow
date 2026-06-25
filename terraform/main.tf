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

locals {
  loop_domain = var.domain != "" ? var.domain : "${var.domain_prefix}.${replace(linode_instance.loop_host.ip_address, ".", "-")}.sslip.io"
}

resource "linode_instance" "loop_host" {
  label            = var.label
  region           = var.region
  type             = var.instance_type
  image            = "linode/ubuntu24.04"
  root_pass        = var.root_password
  tags             = concat(["pmm-agentic-flow"], var.tags)
  watchdog_enabled = true

  metadata {
    user_data = base64encode(templatefile("${path.module}/cloud-init.yaml.tpl", {
      domain                 = local.loop_domain
      acme_email             = var.acme_email
      bootstrap_repo_url     = var.bootstrap_repo_url
      github_token           = var.github_token
      github_copilot_token   = var.github_copilot_token
      litellm_master_key     = var.litellm_master_key
      litellm_model          = var.litellm_model
      agent_canvas_api_key    = coalesce(var.agent_canvas_api_key, var.openhands_api_key)
      agent_canvas_secret_key = var.agent_canvas_secret_key
      agent_canvas_version   = var.agent_canvas_version
      orchestrator_api_key   = var.orchestrator_api_key
      jira_base_url          = var.jira_base_url
      jira_email             = var.jira_email
      jira_api_token         = var.jira_api_token
      jira_webhook_secret    = var.jira_webhook_secret
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
    label    = "allow-http"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "80"
    ipv4     = ["0.0.0.0/0"]
  }

  inbound {
    label    = "allow-https"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "443"
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

output "loop_domain" {
  value       = local.loop_domain
  description = "Public URL hostname (auto sslip.io or custom override)."
}

output "agent_canvas_url" {
  value = "https://${local.loop_domain}/"
}

output "dns_hint" {
  value = var.domain != "" ? "Custom domain — ensure A record: ${local.loop_domain} → ${linode_instance.loop_host.ip_address}" : "No DNS step — sslip.io resolves ${local.loop_domain} automatically."
}

output "openhands_url" {
  value       = "https://${local.loop_domain}/"
  description = "Deprecated alias for agent_canvas_url."
}

output "next_steps" {
  value = <<-EOT
    1. Wait ~5 min for cloud-init (Docker + git clone + compose up)
    2. SSH: ssh root@${linode_instance.loop_host.ip_address}
    3. Check: docker ps
    4. Open: https://${local.loop_domain}/
    5. API key: grep AGENT_CANVAS_API_KEY /etc/pmm-agentic-flow/env
  EOT
}
