variable "metrics_server_chart_version" {
  description = "Helm chart version for metrics-server"
  type        = string
}

variable "metrics_server_image_version" {
  description = "Container image tag for metrics-server"
  type        = string
}

variable "wait_for" {
  description = "Optional dependency to wait for before deploying (e.g., ingress controller readiness)"
  type        = string
  default     = null
}
