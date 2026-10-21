resource "github_actions_secret" "twingate_service_key" {
  repository  = var.github_repository
  secret_name = "TWINGATE_SERVICE_KEY"
  value       = var.twingate_service_key
}

moved {
  from = github_actions_secret.twingate_service_key[0]
  to   = github_actions_secret.twingate_service_key
}

resource "github_actions_secret" "azure_client_id" {
  repository  = var.github_repository
  secret_name = "AZURE_CLIENT_ID"
  value       = azuread_application.github_deploy.client_id
}

resource "github_actions_secret" "azure_tenant_id" {
  repository  = var.github_repository
  secret_name = "AZURE_TENANT_ID"
  value       = var.tenant_id
}

resource "github_actions_secret" "azure_subscription_id" {
  repository  = var.github_repository
  secret_name = "AZURE_SUBSCRIPTION_ID"
  value       = var.azure_subscription_id
}

resource "github_actions_secret" "azure_keyvault_name" {
  repository  = var.github_repository
  secret_name = "AZURE_KEYVAULT_NAME"
  value       = azurerm_key_vault.app_kv.name
}
