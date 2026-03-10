variable "environment_name" {
  description = "The name of the environment"
  type        = string
}

variable "k8s_oidc_issuer_url" {
  description = "The OIDC issuer URL for the Kubernetes cluster"
  type        = string
}

variable "owner" {
  description = "The owner of the resources"
  type        = string
}

variable "hostname" {
  description = "The DNS zone hostname"
  type        = string
}

variable "k8s_host" {
  description = "The Kubernetes API server endpoint"
  type        = string
  sensitive   = true
}

variable "k8s_cluster_ca_certificate" {
  description = "The cluster CA certificate for the Kubernetes cluster"
  type        = string
  sensitive   = true
}

variable "tenant_id" {
  description = "The Azure AD tenant ID"
  type        = string
}

variable "db_jdbc_url" {
  description = "The JDBC URL for the database"
  type        = string
}

variable "db_username" {
  description = "The database username"
  type        = string
}

variable "db_password" {
  description = "The database password"
  type        = string
  sensitive   = true
}

variable "wait_for" {
  description = "Optional dependency to wait for before setting up app (e.g., ingress controller status)"
  type        = string
  default     = null
}
