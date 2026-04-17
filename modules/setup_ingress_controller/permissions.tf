resource "cloudflare_zero_trust_access_application" "traefik_dashboard_access" {
  count                     = var.manage_shared_resources ? 1 : 0
  account_id                = var.cloudflare_account_id
  name                      = "Traefik Dashboard - ${var.environment_name}"
  domain                    = "traefik.${var.dns_zone}"
  session_duration          = "24h"
  type                      = "self_hosted"
  auto_redirect_to_identity = true
  app_launcher_visible      = false
  allowed_idps              = [cloudflare_zero_trust_access_identity_provider.entra_id[0].id]

  policies = [{
    id         = cloudflare_zero_trust_access_policy.cloudflare_sso[0].id
    precedence = 1
  }]
}
