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

variable "azure_storage_account_resource_group_name" {
  description = "The name of the Azure Resource Group where the storage account is located"
  type        = string
}

variable "azure_storage_account_name" {
  description = "The name of the storage account"
  type        = string
}

variable "hostname" {
  description = "The hostname of the ingress controller"
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

variable "wait_for" {
  description = "Optional dependency to wait for before setting up app (e.g., ingress controller status)"
  type        = string
  default     = null
}

variable "additional_dbs" {
  description = "Additional database backup configs to merge into the dbs-config secret (e.g. monitoring stack schemas)."
  type        = any
  default     = []
  sensitive   = true
}
