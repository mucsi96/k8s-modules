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

variable "origin_ipv4" {
  description = "Public IPv4 address of the cluster server; target of the proxied wildcard DNS record"
  type        = string
}

variable "cloudflare_ipv4_cidrs" {
  description = "Cloudflare edge IPv4 ranges trusted for X-Forwarded-* headers"
  type        = list(string)
}

variable "cloudflare_ipv6_cidrs" {
  description = "Cloudflare edge IPv6 ranges trusted for X-Forwarded-* headers"
  type        = list(string)
}

variable "authorized_as" {
  description = "Authorized AS number for firewall rules"
  type        = string
  sensitive   = true
}

variable "edge_firewall_exceptions" {
  description = "POST endpoints allowed to skip the custom firewall rules (bot / threat-score / ASN blocks), only for requests coming from Cloudflare's own network (AS13335). For Cloudflare Workers that authenticate at the application layer, e.g. the Email Worker POSTing bank notifications to the expense tracker. Rate limiting still applies."
  type = list(object({
    description = string
    hostname    = string
    path        = string
  }))
  default = []
}
