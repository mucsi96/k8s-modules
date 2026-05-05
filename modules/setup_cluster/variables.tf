variable "host" {
  description = "DNS name or IP address of the target Linux host accessible over SSH."
  type        = string
}

variable "initial_port" {
  description = "SSH port used to reach the target host."
  type        = number
}

variable "username" {
  description = "Name of the user on the target host."
  type        = string
}

variable "initial_password" {
  description = "Initial password for the user on the target host."
  type        = string
  sensitive   = true
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
  description = "Name of the Azure Storage Account to store OIDC configuration."
  type        = string
}

variable "azure_tenant_id" {
  description = "Azure tenant ID used by the workload identity webhook."
  type        = string
}

variable "local_python_interpreter" {
  description = "Absolute path to the Python interpreter on the Ansible controller (localhost) that has the azure.azcollection requirements installed."
  type        = string
}

variable "apiserver_oidc" {
  description = "Optional Entra OIDC configuration for kube-apiserver. When set, kube-apiserver validates Bearer tokens whose iss matches issuer_url and aud matches client_id, and uses the username_claim (default 'email') as the Kubernetes user name. Pass groups_claim to also map an Entra claim to Kubernetes groups."
  type = object({
    issuer_url     = string
    client_id      = string
    username_claim = optional(string, "email")
    groups_claim   = optional(string)
  })
  default = null
}
