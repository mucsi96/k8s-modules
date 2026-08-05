variable "environment_name" {
  description = "The name of the environment"
  type        = string
}

variable "azure_location" {
  description = "The Azure location to deploy resources"
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

variable "azure_subscription_id" {
  description = "The Azure subscription ID the app deploys into."
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

variable "twingate_service_key" {
  description = "Twingate service key for this app's GitHub Actions pipeline. Required only for local clusters reachable via Twingate; leave null for cloud-hosted clusters."
  type        = string
  sensitive   = true
  default     = null
}

variable "k8s_oidc_config" {
  description = "Rendered kubelogin kubeconfig from setup_cluster. Forwarded to setup_app_base as the app's k8s-config Key Vault secret."
  type        = string
  sensitive   = true
}

variable "client_log_url" {
  description = "URL the app's SPA POSTs client-side telemetry to. Forwarded to setup_app_base, which stores it in this app's Key Vault as `client-log-url`."
  type        = string
}

variable "wait_for" {
  description = "Optional dependency to wait for before setting up app (e.g., ingress controller status)"
  type        = string
  default     = null
}
