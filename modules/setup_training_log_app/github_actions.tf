resource "github_actions_secret" "twingate_service_key" {
  repository      = "training-log-pro"
  secret_name     = "TWINGATE_SERVICE_KEY"
  plaintext_value = var.twingate_service_key
}

resource "github_actions_secret" "k8s_config" {
  repository      = "training-log-pro"
  secret_name     = "K8S_CONFIG"
  plaintext_value = module.create_training_log_namespace.k8s_user_config
}

resource "github_actions_secret" "hostname" {
  repository      = "training-log-pro"
  secret_name     = "HOSTNAME"
  plaintext_value = local.app_hostname
}

resource "github_actions_secret" "api_client_id" {
  repository      = "training-log-pro"
  secret_name     = "API_CLIENT_ID"
  plaintext_value = module.setup_training_log_api.client_id
}

data "docker_login" "current" {}

resource "github_actions_secret" "dockerhub_username" {
  repository      = "training-log-pro"
  secret_name     = "DOCKERHUB_USERNAME"
  plaintext_value = data.docker_login.current.username
}

resource "github_actions_secret" "azure_keyvault_endpoint" {
  repository      = "training-log-pro"
  secret_name     = "AZURE_KEYVAULT_ENDPOINT"
  plaintext_value = azurerm_key_vault.training_log_kv.vault_uri
}

resource "docker_access_token" "training_log" {
  token_label = "training-log-pro"
  scopes      = ["repo:read", "repo:write"]
}

resource "github_actions_secret" "dockerhub_token" {
  repository      = "training-log-pro"
  secret_name     = "DOCKERHUB_TOKEN"
  plaintext_value = docker_access_token.training_log.token
}
