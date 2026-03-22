variable "github_repository" {
  description = "The GitHub repository name for GitHub Actions secrets"
  type        = string
}

variable "environment_name" {
  description = "The name of the environment"
  type        = string
}

variable "app_name" {
  description = "The app name used for Key Vault naming (e.g. hello, training-log)"
  type        = string
}

variable "azure_location" {
  description = "The Azure location to deploy resources"
  type        = string
}

variable "tenant_id" {
  description = "The Azure AD tenant ID"
  type        = string
}

variable "owner" {
  description = "The owner object ID for access policy"
  type        = string
}

variable "use_rbac_authorization" {
  description = "Whether to use RBAC authorization for the Key Vault"
  type        = bool
  default     = false
}

variable "twingate_service_key" {
  description = "Twingate service key"
  type        = string
  sensitive   = true
}

variable "k8s_user_config" {
  description = "The Kubernetes user config from namespace module"
  type        = string
  sensitive   = true
}

variable "app_hostname" {
  description = "The full app hostname"
  type        = string
}

variable "api_client_id" {
  description = "The API application client ID"
  type        = string
}

variable "api_client_secret" {
  description = "The API application client secret"
  type        = string
  sensitive   = true
}

variable "spa_client_id" {
  description = "The SPA application client ID"
  type        = string
}
