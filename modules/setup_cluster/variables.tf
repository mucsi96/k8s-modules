variable "azure_resource_group_name" {
  description = "The name of the Azure Resource Group"
  type        = string
}

variable "azure_location" {
  description = "The Azure location to deploy resources"
  type        = string
}

variable "azure_vm_size" {
  description = "The Azure VM size"
  type        = string
  default     = "Standard_B4pls_v2"
}

variable "azure_vm_disk_size_gb" {
  description = "value of the disk size in GB"
  type        = number
  default     = 30
}

variable "azure_k8s_version" {
  description = "The version of Kubernetes to deploy"
  type        = string
}
