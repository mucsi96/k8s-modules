variable "server_name" {
  description = "Name assigned to the Hetzner Cloud server hosting the cluster."
  type        = string
}

variable "server_type" {
  description = "Hetzner Cloud server type. Defaults to cx42 (8 vCPU / 16 GB RAM)."
  type        = string
  default     = "cx42"
}

variable "location" {
  description = "Hetzner Cloud location code (e.g. nbg1, fsn1, hel1, ash, hil)."
  type        = string
  default     = "nbg1"
}

variable "image" {
  description = "Hetzner Cloud OS image. MicroK8s install requires Ubuntu 24.04 or newer."
  type        = string
  default     = "ubuntu-24.04"
}

variable "username" {
  description = "Non-root Linux user to create on the target host."
  type        = string
  default     = "ubuntu"
}

variable "azure_key_vault_name" {
  description = "Name of the Azure Key Vault to store Kubernetes secrets."
  type        = string
}

variable "azure_subscription_id" {
  description = "Azure subscription ID for Key Vault access."
  type        = string
}

variable "environment_name" {
  description = "Name of the Azure Resource Group containing the Key Vault."
  type        = string
}

variable "storage_account_name" {
  description = "Name of the Azure Storage Account used to publish the OIDC discovery document."
  type        = string
}

variable "azure_tenant_id" {
  description = "Azure tenant ID used by the workload identity webhook."
  type        = string
}
