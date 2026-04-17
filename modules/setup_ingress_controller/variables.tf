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

variable "authorized_as" {
  description = "Authorized AS number for firewall rules"
  type        = string
  sensitive   = true
}

variable "cluster_name" {
  description = "Logical cluster name, used to give tunnels unique names."
  type        = string
  default     = ""
}

variable "manage_shared_resources" {
  description = "Whether this instance manages shared Cloudflare resources (SSO, rulesets, access policies). Only one instance should set this to true."
  type        = bool
  default     = true
}

variable "manage_dns_record" {
  description = "Whether to create the wildcard DNS CNAME. Set to false when DNS is managed at root level for active tunnel switching."
  type        = bool
  default     = true
}
