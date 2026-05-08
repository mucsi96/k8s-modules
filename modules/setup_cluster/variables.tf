variable "host" {
  description = "Public IPv4 address (or DNS name) of the target Hetzner Cloud server."
  type        = string
}

variable "ssh_port" {
  description = "SSH port the server listens on (set by cloud-init at provisioning time)."
  type        = number
}

variable "username" {
  description = "Sudo user on the target host. Must have NOPASSWD sudo configured by cloud-init."
  type        = string
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

variable "known_hosts_file" {
  description = "Per-apply known_hosts file Ansible should pin host keys to. Created by scripts/create.sh under $XDG_RUNTIME_DIR. Falls back to /dev/null when null, which weakens host-key verification to TOFU-per-connect."
  type        = string
  default     = null
}

variable "wait_for" {
  description = "Optional dependency hook (e.g. provision_hetzner_server.agent_loaded) that gates Ansible execution until the SSH key has been loaded into the agent."
  type        = any
  default     = null
}
