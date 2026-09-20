locals {
  name = "observatory"
  apps = concat(var.apps, [{
    name       = "Observatory"
    namespace  = local.name
    repository = "${var.github_repository_owner}/${var.github_repository}"
    url        = "https://${nonsensitive(var.hostname)}"
  }])
}

resource "terraform_data" "ready" { input = var.wait_for }

module "postgres_schema" {
  source   = "../setup_postgres_schema"
  database = var.database
  schema   = "observatory"
}

resource "kubernetes_namespace_v1" "dashboard" {
  metadata { name = local.name }
  depends_on = [terraform_data.ready]
}

# go-app owns the service account. Keep the existing account for Helm's
# --take-ownership handoff so collector RBAC and workload identity remain stable.
removed {
  from = kubernetes_service_account_v1.dashboard
  lifecycle { destroy = false }
}

# Deployment readiness and images only. No secrets, logs, exec, or write access.
resource "kubernetes_role_v1" "reader" {
  for_each = toset([for app in local.apps : app.namespace])
  metadata {
    name      = "observatory-reader"
    namespace = each.value
  }
  rule {
    api_groups = ["apps"]
    resources  = ["deployments"]
    verbs      = ["list"]
  }
  depends_on = [kubernetes_namespace_v1.dashboard]
}

resource "kubernetes_role_binding_v1" "reader" {
  for_each = kubernetes_role_v1.reader
  metadata {
    name      = "observatory-reader"
    namespace = each.value.metadata[0].namespace
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = each.value.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = local.name
    namespace = kubernetes_namespace_v1.dashboard.metadata[0].name
  }
}

resource "kubernetes_config_map_v1" "dashboard" {
  metadata {
    name      = local.name
    namespace = kubernetes_namespace_v1.dashboard.metadata[0].name
  }
  data = { "config.json" = jsonencode({
    environment = var.environment_name
    apps        = local.apps
    auth = {
      tenantId     = var.tenant_id
      clientId     = module.setup_observatory_spa.client_id
      apiClientId  = module.setup_observatory_api.client_id
      clientLogUrl = var.client_log_url
    }
  }) }
}

resource "kubernetes_secret_v1" "github" {
  metadata {
    name      = "observatory-github"
    namespace = kubernetes_namespace_v1.dashboard.metadata[0].name
  }
  data = { token = var.github_token }
}

resource "kubernetes_secret_v1" "database" {
  metadata {
    name      = "observatory-database"
    namespace = kubernetes_namespace_v1.dashboard.metadata[0].name
  }
  data = {
    DB_HOST     = var.database.host
    DB_PORT     = tostring(var.database.port)
    DB_NAME     = var.database.name
    DB_USERNAME = module.postgres_schema.credentials.username
    DB_PASSWORD = module.postgres_schema.credentials.password
    DB_SSLMODE  = "disable"
  }
}

// Workloads are now owned by observatory-app's deployment pipeline. Preserve the
// live resources during the handoff; Helm adopts the same names.
removed {
  from = kubernetes_deployment_v1.dashboard
  lifecycle { destroy = false }
}

removed {
  from = kubernetes_service_v1.dashboard
  lifecycle { destroy = false }
}

# Both registration helpers reference the tenant's shared Microsoft Graph
# service principal. Transfer its state instead of deleting it with the old
# webapp registration during the proxy migration.
moved {
  from = module.registration.azuread_service_principal.msgraph
  to   = module.setup_observatory_spa.azuread_service_principal.msgraph
}

module "setup_observatory_api" {
  source = "../register_api"
  owner  = var.owner

  display_name = "Observatory API"
  roles        = ["readApps"]

  k8s_oidc_issuer_url           = var.k8s_oidc_issuer_url
  k8s_service_account_namespace = kubernetes_namespace_v1.dashboard.metadata[0].name
  k8s_service_account_name      = local.name
}

module "setup_observatory_spa" {
  source = "../register_spa"
  owner  = var.owner

  display_name  = "Observatory SPA"
  redirect_uris = ["https://${var.hostname}/", "http://localhost:4270/"]

  api_id        = module.setup_observatory_api.application_id
  api_client_id = module.setup_observatory_api.client_id
  api_scope_id  = module.setup_observatory_api.scope_id
}

# The legacy `route` resource is removed. go-app and client-app own the
# observatory-route (/api) and observatory-client-route (/) HTTPRoutes.

# Traefik forwards directly to the app, which validates bearer JWTs itself.
resource "kubernetes_network_policy_v1" "dashboard" {
  metadata {
    name      = local.name
    namespace = kubernetes_namespace_v1.dashboard.metadata[0].name
  }
  spec {
    pod_selector {
      match_expressions {
        key      = "app"
        operator = "In"
        values   = [local.name, "${local.name}-client"]
      }
    }
    policy_types = ["Ingress"]
    ingress {
      from {
        namespace_selector {
          match_labels = { "kubernetes.io/metadata.name" = var.ingress_controller_namespace }
        }
        pod_selector {
          match_labels = { "app.kubernetes.io/name" = "traefik" }
        }
      }
      ports {
        port     = "8080"
        protocol = "TCP"
      }
      ports {
        port     = "8000"
        protocol = "TCP"
      }
    }
  }
}

output "url" { value = "https://${nonsensitive(var.hostname)}" }
