variable "environment_name" {
  description = "The name of the environment"
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

variable "playwright_version" {
  description = "The Playwright server Docker image version"
  type        = string
}

variable "wait_for" {
  description = "Optional dependency to wait for before setting up (e.g., ingress controller status)"
  type        = string
  default     = null
}
