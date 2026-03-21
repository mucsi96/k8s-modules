resource "azurerm_key_vault" "training_log_kv" {
  resource_group_name = var.environment_name
  name                = "${var.environment_name}-training-log"
  location            = var.azure_location
  tenant_id           = var.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_key_vault_secret" "training_log_namespace_k8s_user_config" {
  key_vault_id = azurerm_key_vault.training_log_kv.id
  name         = "k8s-config"
  value        = module.create_training_log_namespace.k8s_user_config
}

resource "azurerm_key_vault_secret" "training_log_tenant_id" {
  key_vault_id = azurerm_key_vault.training_log_kv.id
  name         = "tenant-id"
  value        = var.tenant_id
}

resource "azurerm_key_vault_secret" "training_log_api_client_id" {
  key_vault_id = azurerm_key_vault.training_log_kv.id
  name         = "api-client-id"
  value        = module.setup_training_log_api.client_id
}

resource "azurerm_key_vault_secret" "training_log_api_client_secret" {
  key_vault_id = azurerm_key_vault.training_log_kv.id
  name         = "api-client-secret"
  value        = module.setup_training_log_api.client_secret
}

resource "azurerm_key_vault_secret" "training_log_spa_client_id" {
  key_vault_id = azurerm_key_vault.training_log_kv.id
  name         = "spa-client-id"
  value        = module.setup_training_log_spa.client_id
}

resource "azurerm_key_vault_secret" "training_log_hostname" {
  key_vault_id = azurerm_key_vault.training_log_kv.id
  name         = "hostname"
  value        = "training.${var.hostname}"
}

resource "azurerm_key_vault_secret" "training_log_db_url" {
  key_vault_id = azurerm_key_vault.training_log_kv.id
  name         = "db-url"
  value        = var.db_jdbc_url
}

resource "azurerm_key_vault_secret" "training_log_db_username" {
  key_vault_id = azurerm_key_vault.training_log_kv.id
  name         = "db-username"
  value        = var.db_username
}

resource "azurerm_key_vault_secret" "training_log_db_password" {
  key_vault_id = azurerm_key_vault.training_log_kv.id
  name         = "db-password"
  value        = var.db_password
}

resource "azurerm_key_vault_secret" "training_log_twingate_service_key" {
  key_vault_id = azurerm_key_vault.training_log_kv.id
  name         = "twingate-service-key"
  value        = var.twingate_service_key
}
