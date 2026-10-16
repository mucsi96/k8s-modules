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
  description = "API audience used in api-token mode; header-authenticated and login-gated services do not require an API registration."
  type        = string
  default     = null
}

variable "mode" {
  description = "api-token for JWT APIs, email-header for services such as Grafana, or login-gate for services needing only authenticated access."
  type        = string
  default     = "api-token"
  validation {
    condition     = contains(["api-token", "email-header", "login-gate"], var.mode)
    error_message = "Choose api-token, email-header or login-gate."
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
  description = "Pod/node CIDRs from which Traefik actually connects, used by oauth2-proxy to trust forwarded client-IP metadata."
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

variable "public_api_routes" {
  description = "Exact public GET routes for non-sensitive bootstrap metadata needed before login."
  type = list(object({
    path    = string
    service = string
    port    = number
  }))
  default = []
  validation {
    condition = alltrue([for route in var.public_api_routes :
      can(regex("^/api/[^?# ]+$", route.path)) && length(trimspace(route.service)) > 0 &&
      route.port >= 1 && route.port <= 65535 && floor(route.port) == route.port
    ])
    error_message = "Public bootstrap routes require an exact /api/ path, a Service name and an integer port from 1 to 65535."
  }
}

variable "machine_routes" {
  description = "Exact path/method HTTPRoutes for independently authenticated API clients. Backend JWT/token checks remain mandatory."
  type = list(object({
    path    = string
    method  = string
    service = string
    port    = number
  }))
  default = []
}
