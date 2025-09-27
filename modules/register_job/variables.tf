variable "owner" {
  description = "The owner of the resources"
  type        = string
}

variable "display_name" {
  description = "The display name of the Job"
  type        = string
}

variable "api_client_id" {
  description = "The client ID of the API"
  type        = string
}

variable "api_scope_ids" {
  description = "The scope IDs of the API"
  type        = list(string)
}

variable "api_role_ids" {
  description = "The role IDs of the API"
  type        = list(string)
}

variable "api_id" {
  description = "The ID of the API"
  type        = string
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
