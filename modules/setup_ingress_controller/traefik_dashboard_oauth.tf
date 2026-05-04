data "azuread_application_published_app_ids" "well_known" {}

resource "azuread_service_principal" "msgraph" {
  client_id    = data.azuread_application_published_app_ids.well_known.result.MicrosoftGraph
  use_existing = true
}

resource "azuread_application" "traefik_dashboard" {
  display_name     = "Traefik Dashboard - ${var.environment_name}"
  sign_in_audience = "AzureADMyOrg"
  owners           = [var.owner]

  web {
    redirect_uris = [
      "https://${local.traefik_dashboard_host}/oauth2/callback",
    ]

    implicit_grant {
      access_token_issuance_enabled = false
      id_token_issuance_enabled     = true
    }
  }

  required_resource_access {
    resource_app_id = data.azuread_application_published_app_ids.well_known.result.MicrosoftGraph

    resource_access {
      id   = azuread_service_principal.msgraph.oauth2_permission_scope_ids["openid"]
      type = "Scope"
    }

    resource_access {
      id   = azuread_service_principal.msgraph.oauth2_permission_scope_ids["profile"]
      type = "Scope"
    }

    resource_access {
      id   = azuread_service_principal.msgraph.oauth2_permission_scope_ids["email"]
      type = "Scope"
    }
  }
}

resource "azuread_service_principal" "traefik_dashboard" {
  client_id                    = azuread_application.traefik_dashboard.client_id
  owners                       = [var.owner]
  app_role_assignment_required = true
}

resource "azuread_service_principal_delegated_permission_grant" "traefik_dashboard_msgraph" {
  service_principal_object_id          = azuread_service_principal.traefik_dashboard.object_id
  resource_service_principal_object_id = azuread_service_principal.msgraph.object_id
  claim_values                         = ["openid", "profile", "email"]
}

resource "azuread_app_role_assignment" "traefik_dashboard_owner" {
  app_role_id         = "00000000-0000-0000-0000-000000000000"
  principal_object_id = var.owner
  resource_object_id  = azuread_service_principal.traefik_dashboard.object_id
}

resource "azuread_application_password" "traefik_dashboard" {
  application_id = azuread_application.traefik_dashboard.id
  display_name   = "Traefik Dashboard - ${var.environment_name}"
}

resource "random_password" "traefik_dashboard_cookie_secret" {
  length  = 32
  special = false
}

resource "helm_release" "traefik_dashboard_oauth2_proxy" {
  name       = "traefik-dashboard-oauth2-proxy"
  repository = "https://oauth2-proxy.github.io/manifests"
  chart      = "oauth2-proxy"
  version    = var.oauth2_proxy_chart_version
  namespace  = kubernetes_namespace_v1.traefik.metadata[0].name
  wait       = true
  timeout    = 600

  values = [yamlencode({
    image = {
      tag = var.oauth2_proxy_image_version
    }
    config = {
      configFile = <<-EOT
        email_domains = ["*"]
        cookie_secret = "${base64encode(substr(random_password.traefik_dashboard_cookie_secret.result, 0, 32))}"
        cookie_secure = true
        reverse_proxy = true
        skip_provider_button = true
      EOT
    }
    alphaConfig = {
      enabled = true
      configFile = <<-EOT
        injectRequestHeaders:
          - name: Authorization
            values:
              - claim: access_token
                prefix: 'Bearer '
        providers:
          - clientID: ${azuread_application.traefik_dashboard.client_id}
            clientSecret: ${azuread_application_password.traefik_dashboard.value}
            id: entra
            oidcConfig:
              issuerURL: https://login.microsoftonline.com/${var.tenant_id}/v2.0
              audienceClaims:
                - aud
              emailClaim: email
              insecureAllowUnverifiedEmail: true
            provider: oidc
            scope: openid email profile User.Read
        upstreamConfig:
          upstreams:
            - id: traefik-dashboard
              path: /
              uri: http://traefik.${kubernetes_namespace_v1.traefik.metadata[0].name}.svc.cluster.local:9000
      EOT
    }
    ingress = {
      enabled = false
    }
  })]

  depends_on = [helm_release.traefik]
}
