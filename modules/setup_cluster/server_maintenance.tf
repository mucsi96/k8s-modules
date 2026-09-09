resource "azuread_application" "server_maintenance" {
  display_name     = "GitHub Actions server maintenance - ${var.environment_name}"
  sign_in_audience = "AzureADMyOrg"
  owners           = [var.owner]
}

resource "azuread_service_principal" "server_maintenance" {
  client_id = azuread_application.server_maintenance.client_id
  owners    = [var.owner]
}

resource "azuread_application_federated_identity_credential" "server_maintenance" {
  application_id = azuread_application.server_maintenance.id
  display_name   = "github-actions-server-maintenance"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:${var.server_maintenance_github_repository_owner}/${var.server_maintenance_github_repository}:ref:refs/heads/${var.server_maintenance_github_branch}"
}

resource "azurerm_role_assignment" "server_maintenance_secret_reader" {
  for_each = var.server_maintenance_secret_scopes

  scope                = each.value
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azuread_service_principal.server_maintenance.object_id
}

resource "github_actions_secret" "server_maintenance_twingate_service_key" {
  repository  = var.server_maintenance_github_repository
  secret_name = "TWINGATE_SERVICE_KEY"
  value       = var.server_maintenance_twingate_service_key
}

resource "github_actions_secret" "server_maintenance_azure_client_id" {
  repository  = var.server_maintenance_github_repository
  secret_name = "AZURE_CLIENT_ID"
  value       = azuread_application.server_maintenance.client_id
}

resource "github_actions_secret" "server_maintenance_azure_tenant_id" {
  repository  = var.server_maintenance_github_repository
  secret_name = "AZURE_TENANT_ID"
  value       = var.azure_tenant_id
}

resource "github_actions_secret" "server_maintenance_azure_subscription_id" {
  repository  = var.server_maintenance_github_repository
  secret_name = "AZURE_SUBSCRIPTION_ID"
  value       = var.azure_subscription_id
}

resource "github_actions_secret" "server_maintenance_azure_keyvault_name" {
  repository  = var.server_maintenance_github_repository
  secret_name = "AZURE_KEYVAULT_NAME"
  value       = var.azure_key_vault_name
}
