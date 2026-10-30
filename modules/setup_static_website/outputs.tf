output "deployment_config" {
  value = {
    account_name    = azurerm_storage_account.website.name
    hostname        = data.azurerm_storage_account.website.primary_web_host
    assets_base_url = "${azurerm_storage_account.website.primary_blob_endpoint}${azurerm_storage_container.assets.name}/"
  }
  depends_on = [azurerm_role_assignment.deploy, azurerm_role_assignment.deploy_assets]
}
