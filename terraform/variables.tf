variable "linode_token" {
  type        = string
  sensitive   = true
  description = "Linode API token with read/write on Linodes and Firewalls."
}

variable "label" {
  type    = string
  default = "pmm-agentic-flow"
}

variable "region" {
  type    = string
  default = "eu-central"
}

variable "instance_type" {
  type        = string
  default     = "g6-dedicated-8"
  description = "8 vCPU / 16GB — OpenHands + nested sandboxes."
}

variable "root_password" {
  type      = string
  sensitive = true
}

variable "domain" {
  type        = string
  description = "Public hostname for Caddy TLS (e.g. loop.example.com)."
}

variable "acme_email" {
  type = string
}

variable "admin_cidrs" {
  type        = list(string)
  default     = ["0.0.0.0/0"]
  description = "IPv4 sources allowed to SSH (port 22). Use 0.0.0.0/0 for POC."
}

variable "admin_cidrs_v6" {
  type        = list(string)
  default     = ["::/0"]
  description = "IPv6 sources allowed to SSH. Use your-ip/128 or ::/0 for POC."
}

variable "tags" {
  type    = list(string)
  default = []
}

variable "bootstrap_repo_url" {
  type        = string
  description = "Public or token-embed Git URL of this repo — cloud-init clones it on the Linode."
}

variable "github_token" {
  type      = string
  sensitive = true
}

variable "github_copilot_token" {
  type      = string
  sensitive = true
  description = "Token for LiteLLM github/* models (often gh auth token or Copilot token)."
}

variable "litellm_master_key" {
  type      = string
  sensitive = true
}

variable "litellm_model" {
  type    = string
  default = "github/gpt-4.1"
}

variable "agent_canvas_api_key" {
  type        = string
  sensitive   = true
  description = "LOCAL_BACKEND_API_KEY for Agent Canvas (--public mode on VM)."
}

variable "agent_canvas_secret_key" {
  type        = string
  sensitive   = true
  description = "OH_SECRET_KEY — protects stored settings and secrets in Agent Canvas."
}

variable "agent_canvas_version" {
  type        = string
  default     = "latest"
  description = "ghcr.io/openhands/agent-canvas image tag."
}

# Deprecated alias — use agent_canvas_api_key in new tfvars.
variable "openhands_api_key" {
  type      = string
  sensitive = true
  default   = ""
}

variable "orchestrator_api_key" {
  type      = string
  sensitive = true
}

variable "openhands_version" {
  type        = string
  default     = ""
  description = "Deprecated — ignored; use agent_canvas_version."
}

variable "jira_base_url" {
  type    = string
  default = ""
}

variable "jira_email" {
  type    = string
  default = ""
}

variable "jira_api_token" {
  type      = string
  sensitive = true
  default   = ""
}

variable "jira_webhook_secret" {
  type      = string
  sensitive = true
  default   = ""
}
