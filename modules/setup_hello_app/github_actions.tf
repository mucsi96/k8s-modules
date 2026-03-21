resource "github_actions_secret" "twingate_service_key" {
  repository      = "skeleton-app"
  secret_name     = "TWINGATE_SERVICE_KEY"
  plaintext_value = var.twingate_service_key
}

resource "github_actions_secret" "k8s_config" {
  repository      = "skeleton-app"
  secret_name     = "K8S_CONFIG"
  plaintext_value = module.create_hello_namespace.k8s_user_config
}

resource "github_actions_secret" "hostname" {
  repository      = "skeleton-app"
  secret_name     = "HOSTNAME"
  plaintext_value = local.app_hostname
}

resource "github_actions_secret" "api_client_id" {
  repository      = "skeleton-app"
  secret_name     = "API_CLIENT_ID"
  plaintext_value = module.setup_hello_api.client_id
}
