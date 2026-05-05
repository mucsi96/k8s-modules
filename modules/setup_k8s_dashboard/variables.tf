variable "dns_zone" {
  description = "DNS zone used to expose the Headlamp dashboard (e.g. example.com -> k8s.example.com)"
  type        = string
  sensitive   = true
}

variable "tenant_id" {
  description = "Azure AD tenant ID used as the OIDC issuer for oauth2-proxy"
  type        = string
}

variable "client_id" {
  description = "OIDC client ID of the Entra application used by oauth2-proxy and the kube-apiserver"
  type        = string
}

variable "client_secret" {
  description = "OIDC client secret of the Entra application used by oauth2-proxy"
  type        = string
  sensitive   = true
}

variable "valid_email" {
  description = "Email address allowed to sign in to the Headlamp dashboard"
  type        = string
  sensitive   = true
}

variable "headlamp_chart_version" {
  description = "Helm chart version for Headlamp"
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

variable "wait_for" {
  description = "Optional dependency to wait for before deploying (e.g., ingress controller readiness)"
  type        = string
  default     = null
}
