# Cloudflare Rate Limiting Configuration
# This file configures WAF-based rate limiting rules for the zone

# Rate limiting ruleset at the zone level
resource "cloudflare_ruleset" "rate_limiting" {
  zone_id     = var.cloudflare_zone_id
  name        = "Rate Limiting Rules"
  description = "Rate limiting rules for protecting against abuse and DDoS"
  kind        = "zone"
  phase       = "http_ratelimit"

  # Rule 1: Rate limit for API endpoints
  rules {
    action      = "block"
    expression  = "(http.request.uri.path contains \"/api/\")"
    description = "Rate limit API endpoints"
    enabled     = true

    action_parameters {
      response {
        status_code  = 429
        content      = "Too many requests. Please try again later."
        content_type = "text/plain"
      }
    }

    ratelimit {
      characteristics = [
        "ip.src",
        "cf.colo.id"
      ]
      period              = 60
      requests_per_period = 100
      mitigation_timeout  = 600
    }
  }

  # Rule 2: Rate limit for general traffic
  rules {
    action      = "block"
    expression  = "(http.request.uri.path ne \"/health\" and http.request.uri.path ne \"/favicon.ico\")"
    description = "Rate limit general traffic"
    enabled     = true

    action_parameters {
      response {
        status_code  = 429
        content      = "Too many requests. Please try again later."
        content_type = "text/plain"
      }
    }

    ratelimit {
      characteristics = [
        "ip.src"
      ]
      period              = 60
      requests_per_period = 300
      mitigation_timeout  = 300
    }
  }

  # Rule 3: Aggressive rate limiting for login/auth endpoints
  rules {
    action      = "block"
    expression  = "(http.request.uri.path contains \"/auth\" or http.request.uri.path contains \"/login\")"
    description = "Strict rate limit for authentication endpoints"
    enabled     = true

    action_parameters {
      response {
        status_code  = 429
        content      = "Too many authentication attempts. Please try again later."
        content_type = "text/plain"
      }
    }

    ratelimit {
      characteristics = [
        "ip.src"
      ]
      period              = 300
      requests_per_period = 10
      mitigation_timeout  = 1800
    }
  }

  # Rule 4: Rate limit based on country (optional - can be customized)
  rules {
    action      = "managed_challenge"
    expression  = "(ip.geoip.country ne \"US\" and ip.geoip.country ne \"GB\" and ip.geoip.country ne \"CA\" and ip.geoip.country ne \"AU\" and ip.geoip.country ne \"DE\" and ip.geoip.country ne \"FR\")"
    description = "Challenge requests from high-risk regions"
    enabled     = var.enable_geo_based_rate_limiting

    action_parameters {
      response {
        status_code  = 429
        content      = "Please complete the challenge to continue."
        content_type = "text/plain"
      }
    }

    ratelimit {
      characteristics = [
        "ip.src"
      ]
      period              = 60
      requests_per_period = 50
      mitigation_timeout  = 600
    }
  }
}

# Optional: Legacy rate limiting rule (for backwards compatibility)
# Note: This uses the older rate limiting API
# Uncomment if you need legacy rate limiting support

# resource "cloudflare_rate_limit" "api_rate_limit" {
#   zone_id = var.cloudflare_zone_id
#   threshold = 100
#   period = 60
#   match {
#     request {
#       url_pattern = "*${var.dns_zone}/api/*"
#     }
#   }
#   action {
#     mode = "simulate"
#     timeout = 600
#   }
#   correlate {
#     by = "nat"
#   }
#   disabled = false
#   description = "Rate limiting for API endpoints"
# }

# Output the ruleset ID for reference
output "rate_limiting_ruleset_id" {
  value       = cloudflare_ruleset.rate_limiting.id
  description = "The ID of the rate limiting ruleset"
}
