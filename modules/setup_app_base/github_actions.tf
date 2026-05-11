resource "github_actions_secret" "twingate_service_key" {
  count       = var.twingate_service_key == null ? 0 : 1
  repository  = var.github_repository
  secret_name = "TWINGATE_SERVICE_KEY"
  value       = var.twingate_service_key
}

data "docker_login" "current" {}

resource "github_actions_secret" "dockerhub_username" {
  repository  = var.github_repository
  secret_name = "DOCKERHUB_USERNAME"
  value       = data.docker_login.current.username
}

resource "docker_access_token" "app" {
  token_label = var.github_repository
  scopes      = ["repo:read", "repo:write"]
}

resource "github_actions_secret" "dockerhub_token" {
  repository  = var.github_repository
  secret_name = "DOCKERHUB_TOKEN"
  value       = docker_access_token.app.token
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
