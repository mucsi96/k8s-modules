variable "owner" {
  description = "The owner of the resources"
  type        = string
}

variable "display_name" {
  description = "The display name of the API"
  type        = string
}

variable "roles" {
  description = "The roles to create for the API"
  type        = list(string)
  default     = []
}

variable "scopes" {
  description = "The scopes to create for the API"
  type        = list(string)
  default     = []
}

variable "k8s_oidc_issuer_url" {
  description = "The OIDC issuer URL of the Kubernetes cluster"
  type        = string
}

variable "k8s_service_account_namespace" {
  description = "The namespace of the Kubernetes service account"
  type        = string
}

variable "k8s_service_account_name" {
  description = "The name of the Kubernetes service account"
  type        = string
}
