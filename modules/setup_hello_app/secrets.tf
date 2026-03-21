resource "azurerm_key_vault" "hello_kv" {
  resource_group_name = var.environment_name
  name                = "${var.environment_name}-hello"
  location            = var.azure_location
  tenant_id           = var.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_key_vault_secret" "hello_namespace_k8s_user_config" {
  key_vault_id = azurerm_key_vault.hello_kv.id
  name         = "k8s-config"
  value        = module.create_hello_namespace.k8s_user_config
}

resource "azurerm_key_vault_secret" "hello_tenant_id" {
  key_vault_id = azurerm_key_vault.hello_kv.id
  name         = "tenant-id"
  value        = var.tenant_id
}

resource "azurerm_key_vault_secret" "hello_api_client_id" {
  key_vault_id = azurerm_key_vault.hello_kv.id
  name         = "api-client-id"
  value        = module.setup_hello_api.client_id
}

resource "azurerm_key_vault_secret" "hello_api_client_secret" {
  key_vault_id = azurerm_key_vault.hello_kv.id
  name         = "api-client-secret"
  value        = module.setup_hello_api.client_secret
}

resource "azurerm_key_vault_secret" "hello_spa_client_id" {
  key_vault_id = azurerm_key_vault.hello_kv.id
  name         = "spa-client-id"
  value        = module.setup_hello_spa.client_id
}

resource "azurerm_key_vault_secret" "hello_hostname" {
  key_vault_id = azurerm_key_vault.hello_kv.id
  name         = "hostname"
  value        = "hello.${var.hostname}"
}

resource "azurerm_key_vault_secret" "hello_db_url" {
  key_vault_id = azurerm_key_vault.hello_kv.id
  name         = "db-url"
  value        = var.db_jdbc_url
}

resource "azurerm_key_vault_secret" "hello_db_username" {
  key_vault_id = azurerm_key_vault.hello_kv.id
  name         = "db-username"
  value        = var.db_username
}

resource "azurerm_key_vault_secret" "hello_db_password" {
  key_vault_id = azurerm_key_vault.hello_kv.id
  name         = "db-password"
  value        = var.db_password
}
