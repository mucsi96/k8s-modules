variable "environment_name" {
  description = "Azure resource group and Key Vault name used to store platform secrets for the Hetzner deployment."
  type        = string
}

variable "azure_subscription_id" {
  description = "Azure subscription ID used by modules that integrate with Azure services."
  type        = string
}

variable "azure_location" {
  description = "Azure location used by application modules."
  type        = string
}

variable "storage_account_name" {
  description = "Azure storage account that hosts OIDC discovery documents."
  type        = string
}

variable "hetzner_server_name" {
  description = "Server name for the Hetzner machine."
  type        = string
  default     = "k8s-hetzner"
}

variable "hetzner_location" {
  description = "Hetzner location where the server will be created (for example fsn1)."
  type        = string
  default     = "fsn1"
}

variable "hetzner_server_type" {
  description = "Hetzner server type (for example cx22)."
  type        = string
  default     = "cx22"
}

variable "hetzner_image" {
  description = "Image used for the Hetzner server."
  type        = string
  default     = "ubuntu-24.04"
}

variable "hetzner_ssh_username" {
  description = "Bootstrap SSH username created on the Hetzner server."
  type        = string
  default     = "bootstrap"
}
