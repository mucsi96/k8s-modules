variable "hostname" {
  description = "Public hostname where CloudBeaver is exposed (e.g. db.example.com)"
  type        = string
  sensitive   = true
}

variable "tenant_id" {
  description = "Azure AD tenant ID used as the OIDC issuer for oauth2-proxy"
  type        = string
}

variable "client_id" {
  description = "OIDC client ID of the Entra application used by oauth2-proxy"
  type        = string
}

variable "client_secret" {
  description = "OIDC client secret of the Entra application used by oauth2-proxy"
  type        = string
  sensitive   = true
}

variable "valid_email" {
  description = "Email address allowed to sign in to CloudBeaver via Entra"
  type        = string
  sensitive   = true
}

variable "session_redis" {
  description = "Redis backend for oauth2-proxy session storage. Pass connection_url and password from a setup_redis module instance."
  type = object({
    connection_url = string
    password       = string
  })
  sensitive = true
}

variable "cloudbeaver_image_version" {
  description = "Container image tag for dbeaver/cloudbeaver"
  type        = string
}

variable "oauth2_proxy_chart_version" {
  description = "Helm chart version for oauth2-proxy"
  type        = string
}

variable "oauth2_proxy_image_version" {
  description = "Container image tag for oauth2-proxy"
  type        = string
}

variable "database" {
  description = "Connection details for the Postgres instance CloudBeaver connects to. Pre-provisioned as a global connection so the data grid is editable without manual setup."
  type = object({
    name     = string
    host     = string
    port     = number
    username = string
    password = string
  })
  sensitive = true
}

variable "wait_for" {
  description = "Optional dependency to wait for before deploying (e.g., ingress controller readiness)"
  type        = string
  default     = null
}
