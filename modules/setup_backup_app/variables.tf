variable "azure_resource_group_name" {
  description = "The name of the Azure Resource Group"
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
