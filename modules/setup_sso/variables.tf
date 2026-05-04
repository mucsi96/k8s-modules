variable "environment_name" {
  description = "The name of the Azure Resource Group"
  type        = string
}

variable "dns_zone" {
  description = "The DNS zone used to expose the auth service"
  type        = string
  sensitive   = true
}

variable "owner" {
  description = "Object ID of the owner / principal allowed to sign in"
  type        = string
}

variable "tenant_id" {
  description = "Azure AD tenant ID used as the OIDC issuer"
  type        = string
}

variable "traefik_namespace" {
  description = "Namespace where Traefik is deployed"
  type        = string
}

variable "oauth2_proxy_chart_version" {
  description = "The version of the oauth2-proxy Helm chart to deploy"
  type        = string
  default     = "7.7.20" # https://github.com/oauth2-proxy/manifests/releases
}

variable "wait_for" {
  description = "Used to ensure this module waits for upstream dependencies"
  type        = any
  default     = null
}
