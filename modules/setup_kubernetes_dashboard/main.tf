locals {
  app_namespace = "kubernetes-dashboard"
  app_hostname  = "k8s-dashboard.${var.hostname}"
  redirect_url  = "https://${local.app_hostname}/oauth2/callback"
}

resource "kubernetes_namespace_v1" "kubernetes_dashboard" {
  metadata {
    name = local.app_namespace
  }
}

resource "kubernetes_service_account_v1" "dashboard_user" {
  metadata {
    name      = "kubernetes-dashboard-user"
    namespace = kubernetes_namespace_v1.kubernetes_dashboard.metadata[0].name
  }
}

resource "kubernetes_cluster_role_binding_v1" "dashboard_user" {
  metadata {
    name = "kubernetes-dashboard-user"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.dashboard_user.metadata[0].name
    namespace = kubernetes_namespace_v1.kubernetes_dashboard.metadata[0].name
  }

  role_ref {
    kind      = "ClusterRole"
    name      = "cluster-admin"
    api_group = "rbac.authorization.k8s.io"
  }
}

resource "kubernetes_secret_v1" "dashboard_user_token" {
  metadata {
    name      = "kubernetes-dashboard-user-token"
    namespace = kubernetes_namespace_v1.kubernetes_dashboard.metadata[0].name
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account_v1.dashboard_user.metadata[0].name
    }
  }

  type                           = "kubernetes.io/service-account-token"
  wait_for_service_account_token = true
}

data "azuread_application_published_app_ids" "well_known" {}

resource "azuread_service_principal" "msgraph" {
  client_id    = data.azuread_application_published_app_ids.well_known.result.MicrosoftGraph
  use_existing = true
}

resource "azuread_application" "kubernetes_dashboard" {
  display_name     = "Kubernetes Dashboard - ${var.environment_name}"
  sign_in_audience = "AzureADMyOrg"
  owners           = [var.owner]

  web {
    redirect_uris = [local.redirect_url]

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
      id   = azuread_service_principal.msgraph.oauth2_permission_scope_ids["email"]
      type = "Scope"
    }

    resource_access {
      id   = azuread_service_principal.msgraph.oauth2_permission_scope_ids["profile"]
      type = "Scope"
    }

    resource_access {
      id   = azuread_service_principal.msgraph.oauth2_permission_scope_ids["User.Read"]
      type = "Scope"
    }
  }
}

resource "azuread_service_principal" "kubernetes_dashboard" {
  client_id                    = azuread_application.kubernetes_dashboard.client_id
  owners                       = [var.owner]
  tags                         = ["WindowsAzureActiveDirectoryIntegratedApp"]
  app_role_assignment_required = false
}

resource "azuread_service_principal_delegated_permission_grant" "msgraph" {
  service_principal_object_id          = azuread_service_principal.kubernetes_dashboard.object_id
  resource_service_principal_object_id = azuread_service_principal.msgraph.object_id
  claim_values                         = ["openid", "email", "profile", "User.Read"]
}

resource "azuread_application_password" "kubernetes_dashboard" {
  application_id = azuread_application.kubernetes_dashboard.id
  display_name   = "Kubernetes Dashboard - ${var.environment_name}"
}

resource "random_password" "oauth2_cookie_secret" {
  length  = 32
  special = false
}

resource "helm_release" "kubernetes_dashboard" {
  name       = "kubernetes-dashboard"
  repository = "https://kubernetes.github.io/dashboard/"
  chart      = "kubernetes-dashboard"
  version    = var.dashboard_chart_version
  namespace  = kubernetes_namespace_v1.kubernetes_dashboard.metadata[0].name
  wait       = true
  timeout    = 600

  # https://github.com/kubernetes/dashboard/blob/master/charts/kubernetes-dashboard/values.yaml
  values = [yamlencode({
    app = {
      ingress = {
        enabled = false
      }
    }
    kong = {
      proxy = {
        http = {
          enabled = true
        }
      }
    }
  })]
}

resource "helm_release" "oauth2_proxy" {
  name       = "oauth2-proxy"
  repository = "https://oauth2-proxy.github.io/manifests"
  chart      = "oauth2-proxy"
  version    = var.oauth2_proxy_chart_version
  namespace  = kubernetes_namespace_v1.kubernetes_dashboard.metadata[0].name
  wait       = true
  timeout    = 600

  # https://github.com/oauth2-proxy/manifests/blob/main/helm/oauth2-proxy/values.yaml
  values = [yamlencode({
    config = {
      clientID     = azuread_application.kubernetes_dashboard.client_id
      clientSecret = azuread_application_password.kubernetes_dashboard.value
      cookieSecret = random_password.oauth2_cookie_secret.result
      configFile = join("\n", [
        "provider = \"oidc\"",
        "oidc_issuer_url = \"https://login.microsoftonline.com/${var.tenant_id}/v2.0\"",
        "redirect_url = \"${local.redirect_url}\"",
        "upstreams = [\"static://202\"]",
        "email_domains = [\"*\"]",
        "scope = \"openid email profile\"",
        "cookie_secure = true",
        "cookie_domains = [\"${local.app_hostname}\"]",
        "whitelist_domains = [\"${local.app_hostname}\"]",
        "set_xauthrequest = true",
        "skip_provider_button = true",
        "reverse_proxy = true",
      ])
    }
    service = {
      portNumber = 80
    }
  })]
}

resource "helm_release" "kubernetes_dashboard_routes" {
  name      = "kubernetes-dashboard-routes"
  chart     = "${path.module}/charts/dashboard-routes"
  namespace = kubernetes_namespace_v1.kubernetes_dashboard.metadata[0].name

  values = [yamlencode({
    host                   = local.app_hostname
    oauth2ProxyServiceName = "oauth2-proxy"
    oauth2ProxyServicePort = 80
    serviceAccountToken    = kubernetes_secret_v1.dashboard_user_token.data["token"]
  })]

  depends_on = [helm_release.oauth2_proxy]
}
