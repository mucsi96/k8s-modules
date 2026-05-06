resource "azuread_application" "puller" {
  display_name     = var.display_name
  sign_in_audience = "AzureADMyOrg"
  owners           = [var.owner]
}

resource "azuread_service_principal" "puller" {
  client_id = azuread_application.puller.client_id
  owners    = [var.owner]
}

resource "azuread_application_federated_identity_credential" "github_main" {
  application_id = azuread_application.puller.id
  display_name   = "github-actions-main"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = var.github_subject
}

resource "azurerm_role_assignment" "puller_kv_secrets_user" {
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azuread_service_principal.puller.object_id
}
