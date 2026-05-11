variable "display_name" {
  description = "Display name for the Entra application representing the Kubernetes API server (its client_id is what the apiserver puts in --oidc-client-id and what kubelogin passes as --server-id)."
  type        = string
}

variable "owner" {
  description = "Object ID of the Entra application owner."
  type        = string
}
