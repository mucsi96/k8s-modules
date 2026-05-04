resource "cloudflare_zero_trust_access_application" "grafana" {
  account_id                = var.cloudflare_account_id
  name                      = "Grafana - ${var.environment_name}"
  domain                    = local.grafana_host
  session_duration          = "24h"
  type                      = "self_hosted"
  auto_redirect_to_identity = true
  app_launcher_visible      = true
  allowed_idps              = [var.cloudflare_identity_provider_id]

  policies = [{
    id         = var.cloudflare_access_policy_id
    precedence = 1
  }]
}

resource "cloudflare_zero_trust_access_application" "prometheus" {
  account_id                = var.cloudflare_account_id
  name                      = "Prometheus - ${var.environment_name}"
  domain                    = local.prometheus_host
  session_duration          = "24h"
  type                      = "self_hosted"
  auto_redirect_to_identity = true
  app_launcher_visible      = true
  allowed_idps              = [var.cloudflare_identity_provider_id]

  policies = [{
    id         = var.cloudflare_access_policy_id
    precedence = 1
  }]
}

resource "cloudflare_zero_trust_access_application" "kubernetes_dashboard" {
  account_id                = var.cloudflare_account_id
  name                      = "Kubernetes Dashboard - ${var.environment_name}"
  domain                    = local.dashboard_host
  session_duration          = "24h"
  type                      = "self_hosted"
  auto_redirect_to_identity = true
  app_launcher_visible      = true
  allowed_idps              = [var.cloudflare_identity_provider_id]

  policies = [{
    id         = var.cloudflare_access_policy_id
    precedence = 1
  }]
}
