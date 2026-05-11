resource "random_uuid" "user_impersonation_scope_id" {}

# Well-known Azure CLI public client id. Pre-authorizing it on user.impersonation
# lets `az account get-access-token --resource <this-app>` (and therefore
# `kubelogin -l azurecli`) issue tokens without each user running
# `az ad app permission grant` against this resource.
locals {
  azure_cli_client_id = "04b07795-8ddb-461a-bbee-02f9e1bf7b46"
}

resource "azuread_application" "apiserver" {
  display_name     = var.display_name
  sign_in_audience = "AzureADMyOrg"
  owners           = [var.owner]

  api {
    requested_access_token_version = 2

    oauth2_permission_scope {
      admin_consent_description  = "Allow the application to act on behalf of the signed-in user against the Kubernetes API server."
      admin_consent_display_name = "Access Kubernetes API server"
      id                         = random_uuid.user_impersonation_scope_id.result
      type                       = "User"
      user_consent_description   = "Allow the application to access the Kubernetes API server on your behalf."
      user_consent_display_name  = "Access Kubernetes API server"
      value                      = "user.impersonation"
    }
  }

  lifecycle {
    ignore_changes = [
      identifier_uris,
    ]
  }
}

resource "azuread_application_identifier_uri" "apiserver" {
  application_id = azuread_application.apiserver.id
  identifier_uri = "api://${azuread_application.apiserver.client_id}"
}

resource "azuread_service_principal" "apiserver" {
  client_id                    = azuread_application.apiserver.client_id
  owners                       = [var.owner]
  app_role_assignment_required = false
}

resource "azuread_application_pre_authorized" "azure_cli" {
  application_id       = azuread_application.apiserver.id
  authorized_client_id = local.azure_cli_client_id
  permission_ids       = [random_uuid.user_impersonation_scope_id.result]
}
