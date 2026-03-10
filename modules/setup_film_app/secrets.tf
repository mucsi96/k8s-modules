resource "azurerm_key_vault" "film_kv" {
  resource_group_name = var.environment_name
  name                = "${var.environment_name}-film"
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

resource "azurerm_key_vault_secret" "film_namespace_k8s_user_config" {
  key_vault_id = azurerm_key_vault.film_kv.id
  name         = "k8s-config"
  value        = module.create_film_namespace.k8s_user_config
}

resource "azurerm_key_vault_secret" "film_tenant_id" {
  key_vault_id = azurerm_key_vault.film_kv.id
  name         = "tenant-id"
  value        = var.tenant_id
}

resource "azurerm_key_vault_secret" "film_api_client_id" {
  key_vault_id = azurerm_key_vault.film_kv.id
  name         = "api-client-id"
  value        = module.setup_film_api.client_id
}

resource "azurerm_key_vault_secret" "film_api_client_secret" {
  key_vault_id = azurerm_key_vault.film_kv.id
  name         = "api-client-secret"
  value        = module.setup_film_api.client_secret
}

resource "azurerm_key_vault_secret" "film_spa_client_id" {
  key_vault_id = azurerm_key_vault.film_kv.id
  name         = "spa-client-id"
  value        = module.setup_film_spa.client_id
}

resource "azurerm_key_vault_secret" "film_hostname" {
  key_vault_id = azurerm_key_vault.film_kv.id
  name         = "hostname"
  value        = "film.${var.hostname}"
}

resource "azurerm_key_vault_secret" "film_db_url" {
  key_vault_id = azurerm_key_vault.film_kv.id
  name         = "db-url"
  value        = var.db_jdbc_url
}

resource "azurerm_key_vault_secret" "film_db_username" {
  key_vault_id = azurerm_key_vault.film_kv.id
  name         = "db-username"
  value        = var.db_username
}

resource "azurerm_key_vault_secret" "film_db_password" {
  key_vault_id = azurerm_key_vault.film_kv.id
  name         = "db-password"
  value        = var.db_password
}
