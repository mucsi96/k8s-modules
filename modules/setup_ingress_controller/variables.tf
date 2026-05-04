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

variable "oauth2_proxy_namespace" {
  description = "Namespace where the oauth2-proxy that protects the Traefik dashboard runs"
  type        = string
}

variable "oauth2_proxy_service_name" {
  description = "Service name of the oauth2-proxy that protects the Traefik dashboard"
  type        = string
}

variable "oauth2_proxy_service_port" {
  description = "Service port of the oauth2-proxy that protects the Traefik dashboard"
  type        = number
}
