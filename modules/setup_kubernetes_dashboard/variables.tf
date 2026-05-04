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

variable "sso_namespace" {
  description = "Namespace where the shared SSO (oauth2-proxy) runs"
  type        = string
}

variable "sso_service_name" {
  description = "Service name of the shared SSO (oauth2-proxy)"
  type        = string
}

variable "sso_service_port" {
  description = "Service port of the shared SSO (oauth2-proxy)"
  type        = number
}

variable "wait_for" {
  description = "Optional dependency to wait for before deploying the dashboard"
  type        = string
  default     = null
}
