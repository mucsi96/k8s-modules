# The wildcard record stays proxied (orange cloud) so every request keeps
# passing through the Cloudflare edge, where the rulesets in
# cloudflare_ruleset.tf (rate limiting, ASN restriction, bot blocking) are
# enforced. The hcloud firewall in provision_hetzner_server only admits
# Cloudflare's IP ranges on 443, so the edge cannot be bypassed by hitting
# the origin IP directly.
resource "cloudflare_dns_record" "wildcard" {
  zone_id = var.cloudflare_zone_id
  name    = "*"
  content = var.origin_ipv4
  type    = "A"
  ttl     = 1
  proxied = true
}

moved {
  from = cloudflare_dns_record.cname_record
  to   = cloudflare_dns_record.wildcard
}

# Full (strict): the edge only accepts an origin certificate signed by a CA
# it trusts — the Origin CA certificate from origin_certificate.tf.
resource "cloudflare_zone_setting" "ssl" {
  zone_id    = var.cloudflare_zone_id
  setting_id = "ssl"
  value      = "strict"
}

# The origin only listens on 443; plain-HTTP requests are redirected at the
# edge and never reach the server.
resource "cloudflare_zone_setting" "always_use_https" {
  zone_id    = var.cloudflare_zone_id
  setting_id = "always_use_https"
  value      = "on"
}
