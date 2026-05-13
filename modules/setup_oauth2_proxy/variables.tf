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
  description = "OAuth2 scope requested from the OIDC provider. Must include offline_access so Entra issues a refresh_token; oauth2-proxy needs it to refresh the id_token before it expires (cookie_refresh)."
  type        = string
  default     = "openid email profile offline_access User.Read"
}

variable "session_redis" {
  description = "Redis backend for oauth2-proxy session storage. Sessions are stored server-side in the referenced Redis instance so the browser cookie only carries a small session ID, avoiding 'request header too large' errors and Entra login redirect loops when injecting large id_tokens. Pass connection_url and password from modules/setup_redis."
  type = object({
    connection_url = string
    password       = string
  })
  sensitive = true
}

variable "basic_auth_password" {
  description = "When non-empty, oauth2-proxy injects 'Authorization: Basic base64(<authenticated-email>:<this-password>)' on upstream requests (pass_basic_auth). Used to translate an Entra SSO session into a static Basic-auth identity for apps like OpenObserve that don't speak OIDC but accept a reverse-proxy-supplied Authorization header."
  type        = string
  default     = ""
  sensitive   = true
}
