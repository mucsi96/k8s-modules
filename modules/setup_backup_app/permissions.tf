resource "azurerm_role_assignment" "allow_backup_api_to_write_storage_container" {
  scope                = data.azurerm_storage_container.backups_storage_container.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = module.setup_backup_api.resource_object_id
}

