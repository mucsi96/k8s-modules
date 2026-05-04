variable "environment_name" {
  description = "The name of the environment"
  type        = string
}

variable "owner" {
  description = "The owner object ID for the Entra ID application"
  type        = string
}

variable "tenant_id" {
  description = "The Azure AD tenant ID"
  type        = string
}

variable "hostname" {
  description = "The DNS zone hostname (e.g., example.com)"
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

variable "dashboard_chart_version" {
  description = "The version of the kubernetes-dashboard Helm chart"
  type        = string
  default     = "7.10.0" # https://github.com/kubernetes/dashboard/releases
}

variable "wait_for" {
  description = "Optional dependency to wait for before deploying the dashboard"
  type        = string
  default     = null
}
