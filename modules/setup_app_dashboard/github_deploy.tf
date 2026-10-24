resource "azuread_application" "github_deploy" {
  display_name     = "GitHub Actions deploy - ${var.environment_name} - ${local.name}"
  sign_in_audience = "AzureADMyOrg"
  owners           = [var.owner]
}

resource "azuread_service_principal" "github_deploy" {
  client_id = azuread_application.github_deploy.client_id
  owners    = [var.owner]
}

data "github_user" "repository_owner" {
  username = var.github_repository_owner
}

data "github_repository" "app" {
  full_name = "${var.github_repository_owner}/${var.github_repository}"
}

# Match the immutable OIDC subjects used by the other application deployers.
resource "azuread_application_federated_identity_credential" "github_deploy" {
  application_id = azuread_application.github_deploy.id
  display_name   = "github-actions-k8s-deploy"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:${var.github_repository_owner}@${data.github_user.repository_owner.id}/${var.github_repository}@${data.github_repository.app.repo_id}:ref:refs/heads/main"
}

resource "kubernetes_role_v1" "deploy" {
  metadata {
    name      = "observatory-deploy"
    namespace = kubernetes_namespace_v1.dashboard.metadata[0].name
  }
  rule {
    api_groups = ["", "apps", "gateway.networking.k8s.io"]
    resources  = ["deployments", "replicasets", "pods", "services", "serviceaccounts", "secrets", "configmaps", "httproutes"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }
  rule {
    api_groups = ["traefik.io"]
    resources  = ["middlewares", "traefikservices"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }
}

resource "kubernetes_role_binding_v1" "deploy" {
  metadata {
    name      = "observatory-deploy"
    namespace = kubernetes_namespace_v1.dashboard.metadata[0].name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.deploy.metadata[0].name
  }
  subject {
    kind      = "User"
    name      = azuread_service_principal.github_deploy.object_id
    api_group = "rbac.authorization.k8s.io"
  }
}

locals {
  deploy_secrets = {
    AZURE_CLIENT_ID       = azuread_application.github_deploy.client_id
    AZURE_TENANT_ID       = var.tenant_id
    AZURE_SUBSCRIPTION_ID = var.azure_subscription_id
    AZURE_KEYVAULT_NAME   = azurerm_key_vault.app.name
    TWINGATE_SERVICE_KEY  = var.twingate_service_key
  }
}

resource "github_actions_secret" "deploy" {
  for_each    = nonsensitive(toset(keys(local.deploy_secrets)))
  repository  = var.github_repository
  secret_name = each.key
  value       = local.deploy_secrets[each.key]
}

resource "github_actions_variable" "deploy_enabled" {
  repository    = var.github_repository
  variable_name = "DEPLOY_ENABLED"
  value         = "true"
  depends_on = [
    github_actions_secret.deploy,
    azuread_application_federated_identity_credential.github_deploy,
    azurerm_role_assignment.deploy_config,
    module.forward_auth,
    kubernetes_role_binding_v1.deploy,
    kubernetes_role_binding_v1.reader,
    kubernetes_config_map_v1.dashboard,
    kubernetes_secret_v1.github,
  ]
}
