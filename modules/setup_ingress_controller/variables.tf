variable "environment_name" {
  description = "The name of the Azure Resource Group"
  type        = string
}

variable "subscription_id" {
  description = "The subscription ID of the Azure AD"
  type        = string
}

variable "dns_zone" {
  description = "The DNS zone to use for the cluster"
  type        = string
  sensitive   = true
}

variable "traefik_chart_version" {
  description = "The version of the Traefik Helm chart to deploy"
  type        = string
}

variable "traefik_version" {
  description = "The version of Traefik to deploy"
  type        = string
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for the domain to manage"
  type        = string
}

variable "cloudflare_account_id" {
  description = "Cloudflare Account ID"
  type        = string
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token with Zone:Edit permissions"
  type        = string
  sensitive   = true
}

variable "authorized_as" {
  description = "Authorized AS number for firewall rules"
  type        = string
  sensitive   = true
}

variable "tenant_id" {
  description = "Azure AD tenant ID used as the OIDC issuer for the Traefik dashboard"
  type        = string
}

variable "owner" {
  description = "Object ID of the principal allowed to sign in to the Traefik dashboard"
  type        = string
}

variable "oauth2_proxy_chart_version" {
  description = "The version of the oauth2-proxy Helm chart to deploy in front of the Traefik dashboard"
  type        = string
}

variable "oauth2_proxy_image_version" {
  description = "The oauth2-proxy container image tag to deploy in front of the Traefik dashboard"
  type        = string
}

variable "valid_email" {
  description = "The only email address allowed to sign in to the Traefik dashboard"
  type        = string
  sensitive   = true
}

variable "session_redis" {
  description = "Redis backend for oauth2-proxy session storage in front of the Traefik dashboard. Pass connection_url and password from a setup_redis module instance."
  type = object({
    connection_url = string
    password       = string
  })
  sensitive = true
}
