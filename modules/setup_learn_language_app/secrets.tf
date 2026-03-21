resource "azurerm_key_vault" "learn_language_kv" {
  resource_group_name = var.environment_name
  name                = "${var.environment_name}-learn-language"
  location            = var.azure_location
  tenant_id           = var.tenant_id
  sku_name            = "standard"

  access_policy {
    tenant_id = var.tenant_id
    object_id = var.owner

    secret_permissions = [
      "Get",
      "List",
      "Set",
      "Delete",
      "Purge",
    ]
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_key_vault_secret" "learn_language_namespace_k8s_user_config" {
  key_vault_id = azurerm_key_vault.learn_language_kv.id
  name         = "k8s-config"
  value        = module.create_learn_language_namespace.k8s_user_config
}

resource "azurerm_key_vault_secret" "learn_language_tenant_id" {
  key_vault_id = azurerm_key_vault.learn_language_kv.id
  name         = "tenant-id"
  value        = var.tenant_id
}

resource "azurerm_key_vault_secret" "learn_language_api_client_id" {
  key_vault_id = azurerm_key_vault.learn_language_kv.id
  name         = "api-client-id"
  value        = module.setup_learn_language_api.client_id
}

resource "azurerm_key_vault_secret" "learn_language_api_client_secret" {
  key_vault_id = azurerm_key_vault.learn_language_kv.id
  name         = "api-client-secret"
  value        = module.setup_learn_language_api.client_secret
}

resource "azurerm_key_vault_secret" "learn_language_spa_client_id" {
  key_vault_id = azurerm_key_vault.learn_language_kv.id
  name         = "spa-client-id"
  value        = module.setup_learn_language_spa.client_id
}

resource "azurerm_key_vault_secret" "learn_language_hostname" {
  key_vault_id = azurerm_key_vault.learn_language_kv.id
  name         = "hostname"
  value        = local.app_hostname
}

resource "azurerm_key_vault_secret" "learn_language_db_url" {
  key_vault_id = azurerm_key_vault.learn_language_kv.id
  name         = "db-url"
  value        = var.db_jdbc_url
}

resource "azurerm_key_vault_secret" "learn_language_db_username" {
  key_vault_id = azurerm_key_vault.learn_language_kv.id
  name         = "db-username"
  value        = var.db_username
}

resource "azurerm_key_vault_secret" "learn_language_db_password" {
  key_vault_id = azurerm_key_vault.learn_language_kv.id
  name         = "db-password"
  value        = var.db_password
}

resource "azurerm_key_vault_secret" "learn_language_twingate_service_key" {
  key_vault_id = azurerm_key_vault.learn_language_kv.id
  name         = "twingate-service-key"
  value        = var.twingate_service_key
}
