resource "github_actions_secret" "twingate_service_key_backup" {
  repository      = "postgres-azure-backup"
  secret_name     = "TWINGATE_SERVICE_KEY"
  plaintext_value = module.setup_twingate.service_key
}

resource "github_actions_secret" "twingate_service_key_learn_language" {
  repository      = "learn-language"
  secret_name     = "TWINGATE_SERVICE_KEY"
  plaintext_value = module.setup_twingate.service_key
}

resource "github_actions_secret" "twingate_service_key_hello" {
  repository      = "skeleton-app"
  secret_name     = "TWINGATE_SERVICE_KEY"
  plaintext_value = module.setup_twingate.service_key
}

resource "github_actions_secret" "twingate_service_key_training_log" {
  repository      = "training-log-pro"
  secret_name     = "TWINGATE_SERVICE_KEY"
  plaintext_value = module.setup_twingate.service_key
}
