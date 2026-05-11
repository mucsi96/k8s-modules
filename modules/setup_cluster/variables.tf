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

variable "owner" {
  description = "Object ID of the owner for the Entra application that represents the kube-apiserver."
  type        = string
}

variable "local_python_interpreter" {
  description = "Absolute path to the Python interpreter on the Ansible controller (localhost) that has the azure.azcollection requirements installed."
  type        = string
}

variable "wait_for" {
  description = "Optional dependency token (e.g. provision_hetzner_server.ssh_ready). Threaded through ansible_playbook.system_update.extra_vars so Terraform's data-flow tracker serializes Ansible execution behind ssh_ready — i.e. until ssh-agent has the key AND cloud-init has finished bringing sshd up on the custom port. depends_on on a terraform_data sentinel does not serialize correctly here."
  type        = string
  default     = null
}
