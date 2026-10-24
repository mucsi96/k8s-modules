terraform {
  required_providers {
    azurerm = { source = "hashicorp/azurerm" }
  }
}

resource "azurerm_storage_account" "website" {
  name                            = var.name
  resource_group_name             = var.resource_group_name
  location                        = var.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  shared_access_key_enabled       = false
  default_to_oauth_authentication = true
  allow_nested_items_to_be_public = false
}

resource "azurerm_storage_account_static_website" "website" {
  storage_account_id = azurerm_storage_account.website.id
  index_document     = "index.html"
  # No SPA fallback: the authenticated gateway owns document rewriting.
}

# Read the endpoint after hosting is enabled, including on the first apply.
data "azurerm_storage_account" "website" {
  name                = azurerm_storage_account.website.name
  resource_group_name = var.resource_group_name
  depends_on          = [azurerm_storage_account_static_website.website]
}

resource "azurerm_role_assignment" "deploy" {
  scope                = "${azurerm_storage_account.website.id}/blobServices/default/containers/$web"
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = var.deploy_principal_id
  depends_on           = [azurerm_storage_account_static_website.website]
}
