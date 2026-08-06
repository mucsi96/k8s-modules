# Combined per-app SP: reads the app's Key Vault (azurerm_role_assignment in
# secrets.tf) and deploys into the app's namespace (RoleBinding in main.tf).
# AZURE_CLIENT_ID in the app's repo points at this app's client_id.
resource "azuread_application" "github_deploy" {
  display_name     = "GitHub Actions deploy - ${var.environment_name} - ${var.app_name}"
  sign_in_audience = "AzureADMyOrg"
  owners           = [var.owner]
}

resource "azuread_service_principal" "github_deploy" {
  client_id = azuread_application.github_deploy.client_id
  owners    = [var.owner]
}

# Uses GitHub's immutable subject claim format (owner@ID/repo@ID), which is
# what repos created after 2026-07-15 send by default. Repos created before
# that date must be opted in via
# PUT /repos/{owner}/{repo}/actions/oidc/customization/sub
# with use_immutable_subject=true, or their tokens keep the name-based
# subject and won't match this credential.
data "github_user" "repository_owner" {
  username = var.github_repository_owner
}

data "github_repository" "app" {
  full_name = "${var.github_repository_owner}/${var.github_repository}"
}

resource "azuread_application_federated_identity_credential" "github_deploy" {
  application_id = azuread_application.github_deploy.id
  display_name   = "github-actions-k8s-deploy"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:${var.github_repository_owner}@${data.github_user.repository_owner.id}/${var.github_repository}@${data.github_repository.app.repo_id}:ref:refs/heads/main"
}
