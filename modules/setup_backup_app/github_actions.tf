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
