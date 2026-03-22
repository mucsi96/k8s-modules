resource "github_actions_secret" "twingate_service_key" {
  repository      = var.github_repository
  secret_name     = "TWINGATE_SERVICE_KEY"
  plaintext_value = var.twingate_service_key
}

resource "github_actions_secret" "k8s_config" {
  repository      = var.github_repository
  secret_name     = "K8S_CONFIG"
  plaintext_value = var.k8s_user_config
}

resource "github_actions_secret" "hostname" {
  repository      = var.github_repository
  secret_name     = "HOSTNAME"
  plaintext_value = var.app_hostname
}

resource "github_actions_secret" "api_client_id" {
  repository      = var.github_repository
  secret_name     = "API_CLIENT_ID"
  plaintext_value = var.api_client_id
}

data "docker_login" "current" {}

resource "github_actions_secret" "dockerhub_username" {
  repository      = var.github_repository
  secret_name     = "DOCKERHUB_USERNAME"
  plaintext_value = data.docker_login.current.username
}

resource "github_actions_secret" "azure_keyvault_endpoint" {
  repository      = var.github_repository
  secret_name     = "AZURE_KEYVAULT_ENDPOINT"
  plaintext_value = azurerm_key_vault.app_kv.vault_uri
}

resource "docker_access_token" "app" {
  token_label = var.github_repository
  scopes      = ["repo:read", "repo:write"]
}

resource "github_actions_secret" "dockerhub_token" {
  repository      = var.github_repository
  secret_name     = "DOCKERHUB_TOKEN"
  plaintext_value = docker_access_token.app.token
}
