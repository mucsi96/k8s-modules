variable "display_name" {
  description = "Display name for the Entra ID application used by GitHub Actions."
  type        = string
}

variable "owner" {
  description = "Object ID of the Entra application owner."
  type        = string
}

variable "github_subject" {
  description = "Federated credential subject claim (e.g. repo:owner/repo:ref:refs/heads/main)."
  type        = string
}

variable "key_vault_id" {
  description = "Resource ID of the Key Vault to grant secret-read access on."
  type        = string
}
