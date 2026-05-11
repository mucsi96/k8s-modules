# Entra application that represents the kube-apiserver to Entra ID. Its
# client_id is what the apiserver checks against the `aud` claim of every
# Bearer token, and what kubelogin passes as --server-id.
#
# Tokens accepted here come from two flows:
#   - azurecli: human runs `az login` (or CI signs in with azure/login@v3 as a
#     federated SP), then `az account get-access-token --resource <this app>`.
#   - workloadidentity: kubelogin -l workloadidentity exchanges the GitHub
#     OIDC JWT for an Entra access token with this app as the audience.
# The apiserver only checks aud + iss + signature + username_claim, so both
# flows authenticate the same way once a token exists.
#
# user.impersonation is exposed so `az` (which uses v2 .default semantics)
# can mint a token at all, and Azure CLI's well-known public client is
# pre-authorized to skip per-tenant admin consent.

resource "random_uuid" "user_impersonation_scope_id" {}

locals {
  azure_cli_client_id = "04b07795-8ddb-461a-bbee-02f9e1bf7b46"
}

resource "azuread_application" "apiserver" {
  display_name     = "Kubernetes API server - ${var.environment_name}"
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
