resource "github_actions_secret" "twingate_service_key" {
  repository      = "postgres-azure-backup"
  secret_name     = "TWINGATE_SERVICE_KEY"
  plaintext_value = var.twingate_service_key
}

resource "github_actions_secret" "k8s_config" {
  repository      = "postgres-azure-backup"
  secret_name     = "K8S_CONFIG"
  plaintext_value = module.create_backup_namespace.k8s_user_config
}

resource "github_actions_secret" "hostname" {
  repository      = "postgres-azure-backup"
  secret_name     = "HOSTNAME"
  plaintext_value = local.app_hostname
}

resource "github_actions_secret" "api_client_id" {
  repository      = "postgres-azure-backup"
  secret_name     = "API_CLIENT_ID"
  plaintext_value = module.setup_backup_api.client_id
}

data "docker_login" "current" {}

resource "github_actions_secret" "dockerhub_username" {
  repository      = "postgres-azure-backup"
  secret_name     = "DOCKERHUB_USERNAME"
  plaintext_value = data.docker_login.current.username
}

resource "github_actions_secret" "azure_keyvault_endpoint" {
  repository      = "postgres-azure-backup"
  secret_name     = "AZURE_KEYVAULT_ENDPOINT"
  plaintext_value = azurerm_key_vault.backup_kv.vault_uri
}

resource "docker_access_token" "backup" {
  token_label = "postgres-azure-backup"
  scopes      = ["repo:read", "repo:write"]
}

resource "github_actions_secret" "dockerhub_token" {
  repository      = "postgres-azure-backup"
  secret_name     = "DOCKERHUB_TOKEN"
  plaintext_value = docker_access_token.backup.token
}
