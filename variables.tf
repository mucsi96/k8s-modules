variable "manage_wildcard_dns_record" {
  description = "Whether this environment owns the wildcard CNAME record in Cloudflare. Leave true on the primary environment and set to false on secondaries so the wildcard record is managed out-of-band and you can switch infrastructures by editing that single DNS record."
  type        = bool
  default     = true
}
