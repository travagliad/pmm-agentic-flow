variable "linode_token" {
  type        = string
  sensitive   = true
  description = "Linode API token with read/write on Linodes and Firewalls."
}

variable "label" {
  type    = string
  default = "agentic-flow"
}

variable "region" {
  type    = string
  default = "eu-central"
}

variable "instance_type" {
  type        = string
  default     = "g6-standard-4"
  description = "Control plane size (4GB). QA workers use worker_linode_type (8GB)."
}

variable "root_password" {
  type      = string
  sensitive = true
}

variable "admin_cidrs" {
  type        = list(string)
  default     = ["0.0.0.0/0"]
  description = "IPv4 sources allowed to SSH (port 22)."
}

variable "admin_cidrs_v6" {
  type        = list(string)
  default     = ["::/0"]
  description = "IPv6 sources allowed to SSH."
}

variable "tags" {
  type    = list(string)
  default = []
}

variable "bootstrap_repo_url" {
  type        = string
  description = "Git URL of this repo — cloud-init clones it on the Linode."
}

variable "github_token" {
  type      = string
  sensitive = true
}

variable "github_copilot_token" {
  type        = string
  sensitive   = true
  default     = ""
  description = "Copilot CLI auth token (gho_). Defaults to github_token when empty."
}

variable "agent_canvas_api_key" {
  type        = string
  sensitive   = true
  description = "LOCAL_BACKEND_API_KEY — required when Agent Canvas is exposed on :443."
}

variable "agent_canvas_secret_key" {
  type        = string
  sensitive   = true
  description = "OH_SECRET_KEY — encrypts secrets stored by Agent Canvas."
}

variable "agent_canvas_version" {
  type    = string
  default = "latest"
}

variable "openhands_api_key" {
  type        = string
  sensitive   = true
  default     = ""
  description = "Deprecated alias for agent_canvas_api_key."
}

variable "orchestrator_api_key" {
  type        = string
  sensitive   = true
  description = "Protects orchestrator API + Jira webhook (x-api-key header)."
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

variable "cursor_api_key" {
  type      = string
  sensitive = true
  default   = ""
}

variable "ngrok_authtoken" {
  type        = string
  sensitive   = true
  default     = ""
  description = "ngrok authtoken. When set with ngrok_domain, Canvas is reached via ngrok (port 8000 not exposed)."
}

variable "ngrok_domain" {
  type        = string
  default     = ""
  description = "ngrok static domain, e.g. https://your-app.ngrok-free.app"
}

variable "expose_ports_directly" {
  type        = bool
  default     = false
  description = "Open Linode firewall :8000/:8080. Ignored when ngrok_domain is set."
}

variable "data_volume_size" {
  type        = number
  default     = 50
  description = "GB Linode block volume for chats/settings. Set 0 to disable. Detach and reattach to migrate Linodes."
}

variable "worker_root_password" {
  type        = string
  sensitive   = true
  description = "Root password for ephemeral QA worker Linodes."
}

variable "worker_linode_type" {
  type        = string
  default     = "g6-standard-8"
  description = "Linode plan for QA workers (8GB RAM)."
}

variable "worker_linode_region" {
  type    = string
  default = "eu-central"
}

variable "openhands_version" {
  type        = string
  default     = ""
  description = "Deprecated — ignored."
}
