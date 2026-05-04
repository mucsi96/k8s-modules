variable "namespace" {
  description = "The Kubernetes namespace to create and deploy the SSO oauth2-proxy into"
  type        = string
  default     = "sso"
}

variable "client_id" {
  description = "OIDC client ID for the Entra ID application backing the SSO"
  type        = string
}

variable "client_secret" {
  description = "OIDC client secret for the Entra ID application backing the SSO"
  type        = string
  sensitive   = true
}

variable "tenant_id" {
  description = "The Azure AD tenant ID"
  type        = string
}

variable "redirect_url" {
  description = "Public OIDC callback URL (e.g. https://auth.example.com/oauth2/callback)"
  type        = string
}

variable "cookie_domain" {
  description = "Cookie domain shared across protected hosts (e.g. .example.com)"
  type        = string
}

variable "whitelist_domains" {
  description = "Domains the oauth2-proxy is allowed to redirect to after sign-in"
  type        = list(string)
}

variable "chart_version" {
  description = "Helm chart version of oauth2-proxy"
  type        = string
  default     = "7.7.31" # https://github.com/oauth2-proxy/manifests/releases
}
