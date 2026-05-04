variable "dns_zone" {
  description = "The DNS zone used to expose the Kubernetes dashboard"
  type        = string
  sensitive   = true
}

variable "headlamp_chart_version" {
  description = "The version of the Headlamp Helm chart to deploy"
  type        = string
}

variable "auth_middleware_name" {
  description = "Name of the Traefik middleware that gates access via oauth2-proxy"
  type        = string
}

variable "auth_middleware_namespace" {
  description = "Namespace of the Traefik middleware that gates access via oauth2-proxy"
  type        = string
}

variable "wait_for" {
  description = "Used to ensure this module waits for upstream dependencies"
  type        = any
  default     = null
}
