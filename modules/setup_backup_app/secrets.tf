data "azurerm_key_vault" "backup_kv" {
  resource_group_name = var.environment_name
  name                = "${var.environment_name}-backup"
}

resource "azurerm_key_vault_secret" "backup_namespace_k8s_user_config" {
  key_vault_id = data.azurerm_key_vault.backup_kv.id
  name         = "k8s-config"
  value        = module.create_backup_namespace.k8s_user_config
}

resource "azurerm_key_vault_secret" "backup_api_tenant_id" {
  key_vault_id = data.azurerm_key_vault.backup_kv.id
  name         = "tenant-id"
  value        = var.tenant_id
}

resource "azurerm_key_vault_secret" "backup_api_client_id" {
  key_vault_id = data.azurerm_key_vault.backup_kv.id
  name         = "api-client-id"
  value        = module.setup_backup_api.client_id
}

resource "azurerm_key_vault_secret" "backup_api_client_secret" {
  key_vault_id = data.azurerm_key_vault.backup_kv.id
  name         = "api-client-secret"
  value        = module.setup_backup_api.client_secret
}

resource "azurerm_key_vault_secret" "backup_spa_client_id" {
  key_vault_id = data.azurerm_key_vault.backup_kv.id
  name         = "spa-client-id"
  value        = module.setup_backup_spa.client_id
}

resource "azurerm_key_vault_secret" "backup_dbs_config" {
  key_vault_id = data.azurerm_key_vault.backup_kv.id
  name         = "dbs-config"
  value = jsonencode([
    {
      name            = "Learn language"
      host            = "postgres1.db"
      port            = 5432
      database        = "postgres1"
      schema          = "learn_language"
      username        = var.db_username
      password        = var.db_password
      createPlainDump = true
      folderBackups = [
        {
          path = "/app/storage/learn-language"
        }
      ]
      excludeTables = [
        "study_sessions",
        "study_session_cards",
        "model_usage_logs",
        "unhealthy_cards"
      ]
    }
  ])
}

resource "azurerm_key_vault_secret" "backup_hostname" {
  key_vault_id = data.azurerm_key_vault.backup_kv.id
  name         = "hostname"
  value        = "backup.${var.hostname}"
}

resource "azurerm_key_vault_secret" "backup_storage_account_blob_url" {
  key_vault_id = data.azurerm_key_vault.backup_kv.id
  name         = "storage-account-blob-url"
  value        = data.azurerm_storage_account.storage_account.primary_blob_endpoint
}

resource "azurerm_key_vault_secret" "backup_storage_account_container_name" {
  key_vault_id = data.azurerm_key_vault.backup_kv.id
  name         = "storage-account-container-name"
  value        = data.azurerm_storage_container.backups_storage_container.name
}
