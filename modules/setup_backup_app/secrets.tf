locals {
  default_dbs_config = [
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
        "unhealthy_cards",
        "api_tokens"
      ]
    },
    {
      name            = "Training log"
      host            = "postgres1.db"
      port            = 5432
      database        = "postgres1"
      schema          = "training_log"
      username        = var.db_username
      password        = var.db_password
      createPlainDump = true
      folderBackups = [
        {
          path = "/app/storage/training-log"
        }
      ]
      excludeTables = [
        "oauth2_authorized_client"
      ]
    }
  ]
}

resource "azurerm_key_vault_secret" "backup_dbs_config" {
  key_vault_id = module.app_base.key_vault_id
  name         = "dbs-config"
  value        = jsonencode(concat(local.default_dbs_config, var.additional_dbs))
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
