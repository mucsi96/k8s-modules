resource "azurerm_key_vault" "app_kv" {
  resource_group_name        = var.environment_name
  name                       = "${var.environment_name}-${var.app_name}"
  location                   = var.azure_location
  tenant_id                  = var.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = var.use_rbac_authorization

  dynamic "access_policy" {
    for_each = var.use_rbac_authorization ? [] : [1]
    content {
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
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_key_vault_secret" "k8s_user_config" {
  key_vault_id = azurerm_key_vault.app_kv.id
  name         = "k8s-config"
  value        = module.create_namespace.k8s_user_config
}

resource "azurerm_key_vault_secret" "tenant_id" {
  key_vault_id = azurerm_key_vault.app_kv.id
  name         = "tenant-id"
  value        = var.tenant_id
}

resource "azurerm_key_vault_secret" "api_client_id" {
  key_vault_id = azurerm_key_vault.app_kv.id
  name         = "api-client-id"
  value        = var.api_client_id
}

resource "azurerm_key_vault_secret" "api_client_secret" {
  key_vault_id = azurerm_key_vault.app_kv.id
  name         = "api-client-secret"
  value        = var.api_client_secret
}

resource "azurerm_key_vault_secret" "spa_client_id" {
  key_vault_id = azurerm_key_vault.app_kv.id
  name         = "spa-client-id"
  value        = var.spa_client_id
}

resource "azurerm_key_vault_secret" "hostname" {
  key_vault_id = azurerm_key_vault.app_kv.id
  name         = "hostname"
  value        = var.app_hostname
}

resource "azurerm_key_vault_secret" "twingate_service_key" {
  key_vault_id = azurerm_key_vault.app_kv.id
  name         = "twingate-service-key"
  value        = var.twingate_service_key
}
