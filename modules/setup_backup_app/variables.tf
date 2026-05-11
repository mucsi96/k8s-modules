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

variable "azure_subscription_id" {
  description = "The Azure subscription ID the app deploys into."
  type        = string
}

variable "dbs_config" {
  description = "List of database/schema entries the backup tool should snapshot. Each entry is passed straight through to postgres-azure-backup."
  sensitive   = true
  type = list(object({
    name            = string
    host            = string
    port            = number
    database        = string
    schema          = string
    username        = string
    password        = string
    createPlainDump = optional(bool)
    folderBackups   = optional(list(object({ path = string })))
    excludeTables   = optional(list(string))
  }))
}

variable "twingate_service_key" {
  description = "Twingate service key for this app's GitHub Actions pipeline. Required only for local clusters reachable via Twingate; leave null for cloud-hosted clusters."
  type        = string
  sensitive   = true
  default     = null
}

variable "apiserver_client_id" {
  description = "Entra application client_id of the Kubernetes API server. Forwarded to setup_app_base as the kubelogin --server-id."
  type        = string
}

variable "wait_for" {
  description = "Optional dependency to wait for before setting up app (e.g., ingress controller status)"
  type        = string
  default     = null
}
