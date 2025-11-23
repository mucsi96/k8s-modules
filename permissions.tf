data "azurerm_storage_account" "storage_account" {
  name                = "ibari"
  resource_group_name = "ibari"
}

data "azurerm_storage_container" "backups_storage_container" {
  name               = "backups"
  storage_account_id = data.azurerm_storage_account.storage_account.id
}

/**
 * Backup App
 */
resource "azurerm_role_assignment" "allow_backup_api_to_write_storage_container" {
  scope                = data.azurerm_storage_container.backups_storage_container.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = module.setup_backup_app.backup_api_resource_object_id
}

resource "azurerm_role_assignment" "allow_backup_api_to_read_backup_kv" {
  scope                = data.azurerm_key_vault.backup_kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = module.setup_backup_app.backup_api_resource_object_id
}

resource "azuread_app_role_assignment" "allow_admin_user_read_backups" {
  app_role_id         = module.setup_backup_app.backup_api_roles_ids["DatabaseBackupsReader"]
  principal_object_id = data.azurerm_client_config.current.object_id
  resource_object_id  = module.setup_backup_app.backup_api_resource_object_id
}

resource "azuread_app_role_assignment" "allow_admin_user_create_backups" {
  app_role_id         = module.setup_backup_app.backup_api_roles_ids["DatabaseBackupCreator"]
  principal_object_id = data.azurerm_client_config.current.object_id
  resource_object_id  = module.setup_backup_app.backup_api_resource_object_id
}

resource "azuread_app_role_assignment" "allow_admin_user_cleanup_backups" {
  app_role_id         = module.setup_backup_app.backup_api_roles_ids["DatabaseBackupCleaner"]
  principal_object_id = data.azurerm_client_config.current.object_id
  resource_object_id  = module.setup_backup_app.backup_api_resource_object_id
}

resource "azuread_app_role_assignment" "allow_admin_user_restore_backups" {
  app_role_id         = module.setup_backup_app.backup_api_roles_ids["DatabaseBackupRestorer"]
  principal_object_id = data.azurerm_client_config.current.object_id
  resource_object_id  = module.setup_backup_app.backup_api_resource_object_id
}

resource "azuread_app_role_assignment" "allow_admin_user_download_backups" {
  app_role_id         = module.setup_backup_app.backup_api_roles_ids["DatabaseBackupDownloader"]
  principal_object_id = data.azurerm_client_config.current.object_id
  resource_object_id  = module.setup_backup_app.backup_api_resource_object_id
}

/**
 * Learn Language
 */

resource "azuread_app_role_assignment" "allow_admin_user_to_read_learn_language_card_decks" {
  app_role_id         = module.setup_learn_language_api.roles_ids["DeckReader"]
  principal_object_id = data.azurerm_client_config.current.object_id
  resource_object_id  = module.setup_learn_language_api.resource_object_id
}

resource "azuread_app_role_assignment" "allow_admin_user_to_create_learn_language_card_decks" {
  app_role_id         = module.setup_learn_language_api.roles_ids["DeckCreator"]
  principal_object_id = data.azurerm_client_config.current.object_id
  resource_object_id  = module.setup_learn_language_api.resource_object_id
}

resource "azurerm_role_assignment" "allow_learn_language_api_to_read_learn_language_kv" {
  scope                = data.azurerm_key_vault.learn_language_kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = module.setup_learn_language_api.resource_object_id
}
