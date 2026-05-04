variable "environment_name" {
  description = "The name of the Azure Resource Group"
  type        = string
}

variable "dns_zone" {
  description = "The DNS zone to use for the cluster"
  type        = string
  sensitive   = true
}

variable "kubernetes_dashboard_chart_version" {
  description = "The version of the kubernetes-dashboard Helm chart to deploy"
  type        = string
}

variable "dashboard_subdomain" {
  description = "The subdomain to expose the Kubernetes dashboard under"
  type        = string
  default     = "dashboard"
}

variable "cloudflare_account_id" {
  description = "Cloudflare Account ID"
  type        = string
}

variable "cloudflare_access_identity_provider_id" {
  description = "Cloudflare Zero Trust identity provider ID used to authenticate dashboard access"
  type        = string
}

variable "cloudflare_access_policy_id" {
  description = "Cloudflare Zero Trust access policy ID granting authorized users access to the dashboard"
  type        = string
}

variable "traefik_namespace" {
  description = "Namespace where Traefik is installed (used for IngressRoute resources)"
  type        = string
}

variable "wait_for" {
  description = "Resource to wait for before applying this module"
  type        = any
  default     = null
}
