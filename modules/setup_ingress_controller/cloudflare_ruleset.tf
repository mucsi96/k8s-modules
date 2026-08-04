resource "cloudflare_ruleset" "firewall_rules" {
  zone_id = var.cloudflare_zone_id
  kind    = "zone"
  name    = "Firewall Rules"
  phase   = "http_request_firewall_custom"

  # Rules evaluate in order on every request and stop at the first matching
  # block, so the cheapest and most selective rule comes first.
  rules = [
    {
      action      = "block"
      description = "Block Non-Authorized AS"
      enabled     = true
      # 13335 is Cloudflare's own ASN, always allowed: subrequests from
      # Cloudflare Workers (the bank email worker POSTing notifications to
      # the expense tracker) egress from it.
      expression = "(ip.geoip.asnum ne ${var.authorized_as} and ip.geoip.asnum ne 13335)"
    },
    {
      action      = "block"
      description = "Block High Threat Score"
      enabled     = true
      expression  = "(cf.threat_score ge 5)"
    },
    {
      action      = "block"
      description = "Block Bots"
      enabled     = true
      expression  = "(cf.client.bot)"
    }
  ]
}

resource "cloudflare_ruleset" "rate_limiting" {
  zone_id     = var.cloudflare_zone_id
  name        = "Rate Limiting Rules"
  description = "Rate limiting rules for protecting against abuse and DDoS"
  kind        = "zone"
  phase       = "http_ratelimit"

  rules = [{
    action      = "block"
    enabled     = true
    description = "Rate Limit: 1000 requests per 10 seconds"
    expression  = "true"

    action_parameters = {
      response = {
        status_code  = 429
        content      = "Too many requests. Please try again later."
        content_type = "text/plain"
      }
    }

    ratelimit = {
      characteristics     = ["cf.colo.id", "ip.src"]
      period              = 10
      requests_per_period = 1000 # 100 req/s — way above one user, way below a real flood
      mitigation_timeout  = 10
    }
  }]
}
