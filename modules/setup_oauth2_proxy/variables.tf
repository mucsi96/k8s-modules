variable "namespace" {
  description = "The Kubernetes namespace to create and deploy oauth2-proxy into"
  type        = string
}

variable "display_name" {
  description = "Display name of the Entra ID application that backs this oauth2-proxy"
  type        = string
}

variable "app_hostname" {
  description = "Public hostname this oauth2-proxy protects (used for redirect_url, cookie_domain)"
  type        = string
}

variable "owner" {
  description = "Owner object ID for the Entra ID application"
  type        = string
}

variable "tenant_id" {
  description = "The Azure AD tenant ID"
  type        = string
}

variable "chart_version" {
  description = "Helm chart version of oauth2-proxy"
  type        = string
  default     = "7.7.31" # https://github.com/oauth2-proxy/manifests/releases
}
