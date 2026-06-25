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
  ngrok_domain          = var.ngrok_domain != "" && !startswith(var.ngrok_domain, "http") ? "https://${var.ngrok_domain}" : var.ngrok_domain
  use_ngrok             = local.ngrok_domain != ""
  expose_ports_directly = local.use_ngrok ? false : var.expose_ports_directly
  public_url_placeholder = local.use_ngrok ? local.ngrok_domain : "http://__PUBLIC_IP__:8000"
  public_ipv4 = one([
    for addr in sort(tolist(linode_instance.loop_host.ipv4)) : addr
    if !startswith(addr, "192.168.")
  ])
  app_url      = local.use_ngrok ? local.ngrok_domain : "http://${local.public_ipv4}:8080/"
  jira_webhook = local.use_ngrok ? "${trim(local.ngrok_domain, "/")}/hooks/jira" : "http://${local.public_ipv4}:8080/hooks/jira"
  next_steps_ngrok = <<-EOT
    1. Wait ~8 min for cloud-init (orchestrator + ngrok agent)
    2. ngrok dashboard: if dismay-concierge-gem is a Cloud Endpoint with forward-internal→default.internal,
       delete that policy or the Cloud Endpoint — the VM agent must own this URL.
    3. Orchestrator: ${trim(local.ngrok_domain, "/")}/
    4. Jira webhook: ${trim(local.ngrok_domain, "/")}/hooks/jira
    5. First sandbox: POST ${trim(local.ngrok_domain, "/")}/orchestrator/tickets/transition (see scripts/simulate-transition.sh)
    6. SSH (admin only): ssh root@${local.public_ipv4}
  EOT
  next_steps_direct = <<-EOT
    1. Wait ~8 min for cloud-init
    2. Orchestrator: http://${local.public_ipv4}:8080/
    3. Jira webhook: http://${local.public_ipv4}:8080/hooks/jira
    4. Chat runners: one Linode per ticket — Canvas URL in Jira comments
    5. Set ngrok_domain + ngrok_authtoken for a stable public webhook URL
  EOT
  next_steps = local.use_ngrok ? local.next_steps_ngrok : local.next_steps_direct
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
      bootstrap_repo_url      = var.bootstrap_repo_url
      github_token            = var.github_token
      github_copilot_token    = var.github_copilot_token != "" ? var.github_copilot_token : var.github_token
      agent_canvas_api_key    = var.agent_canvas_api_key
      agent_canvas_secret_key = var.agent_canvas_secret_key
      agent_canvas_version    = var.agent_canvas_version
      api_secret              = var.api_secret
      jira_base_url           = var.jira_base_url
      jira_email              = var.jira_email
      jira_api_token          = var.jira_api_token
      cursor_api_key          = var.cursor_api_key
      linode_token            = var.linode_token
      worker_root_password    = var.worker_root_password
      ngrok_authtoken         = var.ngrok_authtoken
      ngrok_domain            = local.ngrok_domain
      expose_ports_directly   = local.expose_ports_directly
      public_url_placeholder  = local.public_url_placeholder
    }))
  }
}

resource "linode_volume" "data" {
  count     = var.data_volume_size > 0 ? 1 : 0
  label     = "${var.label}-data"
  region    = var.region
  size      = var.data_volume_size
  linode_id = linode_instance.loop_host.id
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

  dynamic "inbound" {
    for_each = local.expose_ports_directly ? [1] : []
    content {
      label    = "allow-orchestrator"
      action   = "ACCEPT"
      protocol = "TCP"
      ports    = "8080"
      ipv4     = ["0.0.0.0/0"]
    }
  }

  inbound_policy  = "DROP"
  outbound_policy = "ACCEPT"
  linodes         = [linode_instance.loop_host.id]
}

output "instance_id" {
  value = linode_instance.loop_host.id
}

output "public_ip" {
  value       = local.public_ipv4
  description = "Primary public IPv4 (SSH only when ngrok is enabled)."
}

output "data_volume_id" {
  value       = var.data_volume_size > 0 ? linode_volume.data[0].id : null
  description = "Detach and reattach this volume to migrate chats to a new Linode."
}

output "ssh_command" {
  value = "ssh root@${local.public_ipv4}"
}

output "app_url" {
  value       = local.app_url
  description = "Orchestrator public URL (ngrok domain or direct IP :8080)."
}

output "jira_webhook_url" {
  value = local.jira_webhook
}

output "next_steps" {
  value = local.next_steps
}
