variable "dns_zone" {
  description = "DNS zone used by the cluster."
  type        = string
  sensitive   = true
}

variable "k8s_config" {
  description = "Admin kubeconfig from setup_cluster used only to wait for bundled Traefik Gateway readiness."
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID to manage."
  type        = string
}

variable "origin_ipv4" {
  description = "Public IPv4 address of the Netcup cluster server."
  type        = string
}

variable "cloudflare_ipv4_cidrs" {
  description = "Cloudflare edge IPv4 ranges trusted for forwarded headers."
  type        = list(string)
}

variable "cloudflare_ipv6_cidrs" {
  description = "Cloudflare edge IPv6 ranges trusted for forwarded headers."
  type        = list(string)
}

variable "authorized_as" {
  description = "Authorized AS number for Cloudflare firewall rules."
  type        = string
  sensitive   = true
}

variable "edge_firewall_exceptions" {
  description = "Authenticated POST endpoints allowed to skip selected Cloudflare custom firewall rules."
  type = list(object({
    description = string
    hostname    = string
    path        = string
  }))
  default = []
}
