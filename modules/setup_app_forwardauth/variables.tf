variable "name" {
  type = string
}

variable "namespace" {
  type = string
}

variable "hostname" {
  type = string
}

variable "tenant_id" {
  type = string
}

variable "client_id" {
  type = string
}

variable "client_secret" {
  type      = string
  sensitive = true
}

variable "api_client_id" {
  type = string
}

variable "chart_version" {
  description = "Explicit published oauth2-proxy-forwardauth chart version."
  type        = string
  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+(-[0-9A-Za-z.-]+)?$", var.chart_version))
    error_message = "Pin a published semantic chart version; empty/latest versions are not supported."
  }
}

variable "session_redis" {
  type = object({
    connection_url = string
    password       = string
  })
  sensitive = true
}

variable "trusted_proxy_cidrs" {
  description = "Pod/node CIDRs from which Traefik actually connects; the proxy NetworkPolicy further limits callers to Traefik."
  type        = list(string)
  validation {
    condition     = length(var.trusted_proxy_cidrs) > 0 && alltrue([for cidr in var.trusted_proxy_cidrs : can(cidrhost(cidr, 0))])
    error_message = "Supply at least one valid trusted Traefik source CIDR."
  }
}

variable "gateway_parent_ref" {
  type = object({
    name         = string
    namespace    = string
    section_name = string
  })
}

variable "protected_apps" {
  description = "Existing chart release names/ports to admit only from Traefik, preserving monitoring on management ports."
  type = map(object({
    port            = number
    management_port = optional(number)
  }))
}

variable "machine_routes" {
  description = "Exact, independently authenticated host/path/method routes. Backend JWT/token checks remain mandatory."
  type = list(object({
    path    = string
    method  = string
    service = string
    port    = number
  }))
  default = []
}
