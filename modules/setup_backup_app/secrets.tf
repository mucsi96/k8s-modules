resource "azurerm_key_vault_secret" "backup_dbs_config" {
  key_vault_id = module.app_base.key_vault_id
  name         = "dbs-config"
  value        = jsonencode(var.dbs_config)
}

resource "azurerm_key_vault_secret" "backup_storage_account_blob_url" {
  key_vault_id = module.app_base.key_vault_id
  name         = "storage-account-blob-url"
  value        = data.azurerm_storage_account.storage_account.primary_blob_endpoint
}

resource "azurerm_key_vault_secret" "backup_storage_account_container_name" {
  key_vault_id = module.app_base.key_vault_id
  name         = "storage-account-container-name"
  value        = data.azurerm_storage_container.backups_storage_container.name
}
