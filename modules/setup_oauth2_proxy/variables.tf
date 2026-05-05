variable "name" {
  description = "Resource name prefix used for the oauth2-proxy Helm release, IngressRoute and middleware"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace where oauth2-proxy and the IngressRoute will be created"
  type        = string
}

variable "hostname" {
  description = "Public hostname protected by oauth2-proxy (e.g. traefik.example.com)"
  type        = string
}

variable "display_name" {
  description = "Display name used for the registered Entra application (environment is appended)"
  type        = string
}

variable "environment_name" {
  description = "Environment name appended to the Entra application display name"
  type        = string
}

variable "owner" {
  description = "Object ID of the Entra principal that owns the registered application"
  type        = string
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

variable "redirect_root_to" {
  description = "Optional path to redirect requests at '/' to (e.g. '/dashboard/'). Set to null to disable."
  type        = string
  default     = null
}

variable "entry_point" {
  description = "Traefik entry point used by the IngressRoute"
  type        = string
  default     = "web"
}
