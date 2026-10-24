output "deployment_config" {
  value = {
    account_name = azurerm_storage_account.website.name
    hostname     = data.azurerm_storage_account.website.primary_web_host
  }
  depends_on = [azurerm_role_assignment.deploy]
}
