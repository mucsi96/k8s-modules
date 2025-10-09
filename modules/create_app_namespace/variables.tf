variable "environment_name" {
  description = "The name of the environment"
  type        = string
}

variable "k8s_namespace" {
  description = "The name of the Kubernetes namespace to create"
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
