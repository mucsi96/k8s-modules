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
