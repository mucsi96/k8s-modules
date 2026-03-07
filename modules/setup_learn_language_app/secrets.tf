data "azurerm_key_vault" "learn_language_kv" {
  resource_group_name = var.environment_name
  name                = "${var.environment_name}-learn-language"
}

resource "azurerm_key_vault_secret" "learn_language_namespace_k8s_user_config" {
  key_vault_id = data.azurerm_key_vault.learn_language_kv.id
  name         = "k8s-config"
  value        = module.create_learn_language_namespace.k8s_user_config
}

resource "azurerm_key_vault_secret" "learn_language_tenant_id" {
  key_vault_id = data.azurerm_key_vault.learn_language_kv.id
  name         = "tenant-id"
  value        = var.tenant_id
}

resource "azurerm_key_vault_secret" "learn_language_api_client_id" {
  key_vault_id = data.azurerm_key_vault.learn_language_kv.id
  name         = "api-client-id"
  value        = module.setup_learn_language_api.client_id
}

resource "azurerm_key_vault_secret" "learn_language_api_client_secret" {
  key_vault_id = data.azurerm_key_vault.learn_language_kv.id
  name         = "api-client-secret"
  value        = module.setup_learn_language_api.client_secret
}

resource "azurerm_key_vault_secret" "learn_language_spa_client_id" {
  key_vault_id = data.azurerm_key_vault.learn_language_kv.id
  name         = "spa-client-id"
  value        = module.setup_learn_language_spa.client_id
}

resource "azurerm_key_vault_secret" "learn_language_hostname" {
  key_vault_id = data.azurerm_key_vault.learn_language_kv.id
  name         = "hostname"
  value        = "language.${var.hostname}"
}

resource "azurerm_key_vault_secret" "learn_language_db_url" {
  key_vault_id = data.azurerm_key_vault.learn_language_kv.id
  name         = "db-url"
  value        = var.db_jdbc_url
}

resource "azurerm_key_vault_secret" "learn_language_db_username" {
  key_vault_id = data.azurerm_key_vault.learn_language_kv.id
  name         = "db-username"
  value        = var.db_username
}

resource "azurerm_key_vault_secret" "learn_language_db_password" {
  key_vault_id = data.azurerm_key_vault.learn_language_kv.id
  name         = "db-password"
  value        = var.db_password
}
