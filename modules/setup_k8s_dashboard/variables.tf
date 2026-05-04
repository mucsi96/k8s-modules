variable "dns_zone" {
  description = "The DNS zone used to expose the Kubernetes dashboard"
  type        = string
  sensitive   = true
}

variable "dashboard_chart_version" {
  description = "The version of the kubernetes-dashboard Helm chart to deploy"
  type        = string
}

variable "auth_middleware_name" {
  description = "Name of the Traefik middleware used to protect the Kubernetes dashboard"
  type        = string
}

variable "auth_middleware_namespace" {
  description = "Namespace of the Traefik middleware used to protect the Kubernetes dashboard"
  type        = string
}

variable "bearer_token" {
  description = "Bearer token injected into the Authorization header so the dashboard skips its login screen"
  type        = string
  sensitive   = true
}

variable "wait_for" {
  description = "Used to ensure this module waits for upstream dependencies"
  type        = any
  default     = null
}
