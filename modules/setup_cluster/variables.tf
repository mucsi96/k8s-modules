variable "host" {
  description = "Twingate-reachable public IPv4 address or DNS name of the Netcup cluster server."
  type        = string
}

variable "ssh_port" {
  description = "SSH port configured during Netcup image installation."
  type        = number
}

variable "username" {
  description = "Passwordless sudo user on the Debian 13 host."
  type        = string
}

variable "k3s_version" {
  description = "Pinned k3s release. This also pins the bundled Traefik and Metrics Server versions."
  type        = string
  default     = "v1.36.4+k3s1"
}

variable "k3s_api_port" {
  description = "k3s Kubernetes API port. Use the same value for setup_twingate_access.k8s_port."
  type        = number
  default     = 6443

  validation {
    condition     = var.k3s_api_port >= 1 && var.k3s_api_port <= 65535
    error_message = "k3s_api_port must be a valid TCP port."
  }
}

variable "azure_key_vault_name" {
  description = "Name of the Azure Key Vault used for Kubernetes credentials."
  type        = string
}

variable "azure_subscription_id" {
  description = "Azure subscription ID for Key Vault access."
  type        = string
}

variable "environment_name" {
  description = "Name of the Azure resource group containing the Key Vault."
  type        = string
}

variable "storage_account_name" {
  description = "Azure Storage Account that publishes workload identity OIDC documents."
  type        = string
}

variable "azure_tenant_id" {
  description = "Azure tenant ID used by workload identity and API server authentication."
  type        = string
}

variable "owner" {
  description = "Object ID of the owner for the Entra applications created by this module."
  type        = string
}

variable "local_python_interpreter" {
  description = "Controller Python interpreter containing azure.azcollection requirements."
  type        = string
}

variable "wait_for" {
  description = "Optional provision_server.ssh_ready dependency token."
  type        = string
  default     = null
}
