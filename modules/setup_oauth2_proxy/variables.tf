variable "name" {
  description = "Resource name prefix used for the oauth2-proxy Helm release"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace where oauth2-proxy is deployed"
  type        = string
}

variable "client_id" {
  description = "OIDC client ID for the registered Entra application"
  type        = string
}

variable "client_secret" {
  description = "OIDC client secret for the registered Entra application"
  type        = string
  sensitive   = true
}

variable "tenant_id" {
  description = "Azure AD tenant ID used as the OIDC issuer"
  type        = string
}

variable "valid_email" {
  description = "Email address allowed to sign in via oauth2-proxy"
  type        = string
  sensitive   = true
}

variable "oauth2_proxy_chart_version" {
  description = "Helm chart version for oauth2-proxy"
  type        = string
}

variable "oauth2_proxy_image_version" {
  description = "Container image tag for oauth2-proxy"
  type        = string
}

variable "upstream_uri" {
  description = "Upstream service URI that authenticated requests are forwarded to"
  type        = string
}

variable "inject_request_headers" {
  description = "Headers oauth2-proxy injects into upstream requests (alphaConfig.injectRequestHeaders). Used e.g. to forward the Entra access token as 'Authorization: Bearer ...' to Headlamp."
  type = list(object({
    name = string
    values = list(object({
      claim  = string
      prefix = optional(string)
    }))
  }))
  default = []
}

variable "scope" {
  description = "OAuth2 scope requested from the OIDC provider"
  type        = string
  default     = "openid email profile User.Read"
}

variable "session_redis" {
  description = "Optional external Redis backend for oauth2-proxy session storage. When set, sessions are stored in the referenced Redis instance and the browser cookie only carries a small session ID, avoiding 'request header too large' errors and Entra login redirect loops when injecting large id_tokens. When null, sessions live entirely in the browser cookie. Pass connection_url and password from modules/setup_redis."
  type = object({
    connection_url = string
    password       = string
  })
  default   = null
  sensitive = true
}
