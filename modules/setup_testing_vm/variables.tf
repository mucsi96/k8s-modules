variable "name" {
  description = "The name of the VM."
  type        = string
}

variable "ssh_user" {
  description = "The SSH username for the VM."
  type        = string
}

variable "hetzner_api_token" {
  description = "API token for Hetzner Cloud."
  type        = string
  sensitive   = true
}

