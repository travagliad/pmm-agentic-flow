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
  tags             = concat(["pmm-agentic-flow"], var.tags)
  watchdog_enabled = true

  metadata {
    user_data = base64encode(templatefile("${path.module}/cloud-init.yaml.tpl", {
      domain                 = var.domain
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

output "dns_hint" {
  value = "Create an A record: ${var.domain} → ${linode_instance.loop_host.ip_address}"
}

output "openhands_url" {
  value = "https://${var.domain}/"
}

output "next_steps" {
  value = <<-EOT
    1. Point DNS A record ${var.domain} → ${linode_instance.loop_host.ip_address}
    2. Wait ~5 min for cloud-init (Docker + git clone + compose up)
    3. SSH: ssh root@${linode_instance.loop_host.ip_address}
    4. Check: journalctl -u cloud-final -f  OR  docker ps
    5. Open: https://${var.domain}/
  EOT
}
