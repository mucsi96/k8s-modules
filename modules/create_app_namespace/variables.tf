variable "azure_resource_group_name" {
  description = "The name of the Azure Resource Group"
  type        = string
}

variable "k8s_namespace" {
  description = "The name of the Kubernetes namespace to create"
  type        = string
}
