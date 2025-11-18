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

variable "letsencrypt_email" {
  description = "The email address to use for Let's Encrypt"
  type        = string
  sensitive   = true
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

variable "cloudflare_team_domain" {
  description = "Cloudflare Team Domain (e.g., example.cloudflareaccess.com)"
  type        = string
}

variable "enable_geo_based_rate_limiting" {
  description = "Enable geographic-based rate limiting for high-risk regions"
  type        = bool
  default     = false
}
