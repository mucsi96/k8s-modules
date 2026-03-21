resource "github_actions_secret" "twingate_service_key" {
  repository      = "learn-language"
  secret_name     = "TWINGATE_SERVICE_KEY"
  plaintext_value = var.twingate_service_key
}

resource "github_actions_secret" "k8s_config" {
  repository      = "learn-language"
  secret_name     = "K8S_CONFIG"
  plaintext_value = module.create_learn_language_namespace.k8s_user_config
}

resource "github_actions_secret" "hostname" {
  repository      = "learn-language"
  secret_name     = "HOSTNAME"
  plaintext_value = local.app_hostname
}

resource "github_actions_secret" "api_client_id" {
  repository      = "learn-language"
  secret_name     = "API_CLIENT_ID"
  plaintext_value = module.setup_learn_language_api.client_id
}

resource "docker_access_token" "learn_language" {
  token_label = "learn-language"
  scopes      = ["repo:read", "repo:write"]
}

resource "github_actions_secret" "dockerhub_token" {
  repository      = "learn-language"
  secret_name     = "DOCKERHUB_TOKEN"
  plaintext_value = docker_access_token.learn_language.token
}
