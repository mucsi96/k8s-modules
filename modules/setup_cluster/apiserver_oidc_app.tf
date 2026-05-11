# Dedicated Entra application that the kube-apiserver trusts as its OIDC
# audience. Deliberately separate from cluster_monitor (the Headlamp
# dashboard's OIDC client): if those were the same app, an id_token leaked
# from oauth2-proxy's browser session would be a valid Bearer for the
# apiserver as the signed-in user — and that user has cluster-admin via
# the oidc_human_admin binding. With the apps split, the dashboard's
# id_token has aud = cluster_monitor and is rejected by the apiserver
# (--oidc-client-id = apiserver below).
#
# kubelogin sets --server-id to this app's client_id so the tokens it mints
# carry aud = apiserver. user.impersonation is exposed and Azure CLI is
# pre-authorized so `az account get-access-token --resource <this app>`
# (and therefore `kubelogin -l azurecli`) issues tokens without per-tenant
# admin consent.

resource "random_uuid" "user_impersonation_scope_id" {}

locals {
  azure_cli_client_id = "04b07795-8ddb-461a-bbee-02f9e1bf7b46"
}

resource "azuread_application" "apiserver" {
  display_name     = "Kubernetes apiserver - ${var.environment_name}"
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

resource "azuread_service_principal" "apiserver" {
  client_id                    = azuread_application.apiserver.client_id
  owners                       = [var.owner]
  tags                         = ["WindowsAzureActiveDirectoryIntegratedApp"]
  app_role_assignment_required = false
}

resource "azuread_application_pre_authorized" "apiserver_azure_cli" {
  application_id       = azuread_application.apiserver.id
  authorized_client_id = local.azure_cli_client_id
  permission_ids       = [random_uuid.user_impersonation_scope_id.result]
}
