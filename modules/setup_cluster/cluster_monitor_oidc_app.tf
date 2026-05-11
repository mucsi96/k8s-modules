# Entra application that serves two roles:
#
#   1. Confidential OIDC web client for the cluster monitor (Headlamp)
#      dashboard. oauth2-proxy completes the auth-code flow against Entra
#      with this client_id/client_secret; the resulting id_token is injected
#      as the Authorization: Bearer header into Headlamp, and Headlamp
#      forwards it to the apiserver as the user's identity.
#
#   2. Resource app the kube-apiserver trusts. --oidc-client-id below points
#      at this same client_id, so the dashboard's id_token AND any token
#      kubelogin mints (--server-id = this app's client_id) are both accepted.
#
# user.impersonation is exposed and Azure CLI is pre-authorized so
# `az account get-access-token --resource <this app>` (and therefore
# `kubelogin -l azurecli`) issues tokens without per-tenant admin consent.

data "azuread_application_published_app_ids" "well_known" {}

resource "azuread_service_principal" "msgraph" {
  client_id    = data.azuread_application_published_app_ids.well_known.result.MicrosoftGraph
  use_existing = true
}

resource "random_uuid" "user_impersonation_scope_id" {}

locals {
  azure_cli_client_id = "04b07795-8ddb-461a-bbee-02f9e1bf7b46"
}

resource "azuread_application" "cluster_monitor" {
  display_name     = "Cluster monitor - ${var.environment_name}"
  sign_in_audience = "AzureADMyOrg"
  owners           = [var.owner]

  web {
    redirect_uris = var.cluster_monitor_redirect_uris

    implicit_grant {
      access_token_issuance_enabled = false
      id_token_issuance_enabled     = true
    }
  }

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

  required_resource_access {
    resource_app_id = data.azuread_application_published_app_ids.well_known.result.MicrosoftGraph

    resource_access {
      id   = azuread_service_principal.msgraph.oauth2_permission_scope_ids["email"]
      type = "Scope"
    }

    resource_access {
      id   = azuread_service_principal.msgraph.oauth2_permission_scope_ids["openid"]
      type = "Scope"
    }

    resource_access {
      id   = azuread_service_principal.msgraph.oauth2_permission_scope_ids["profile"]
      type = "Scope"
    }

    resource_access {
      id   = azuread_service_principal.msgraph.oauth2_permission_scope_ids["offline_access"]
      type = "Scope"
    }

    resource_access {
      id   = azuread_service_principal.msgraph.oauth2_permission_scope_ids["User.Read"]
      type = "Scope"
    }
  }

  lifecycle {
    ignore_changes = [
      identifier_uris,
    ]
  }
}

resource "azuread_service_principal" "cluster_monitor" {
  client_id                    = azuread_application.cluster_monitor.client_id
  owners                       = [var.owner]
  tags                         = ["WindowsAzureActiveDirectoryIntegratedApp"]
  app_role_assignment_required = true
}

resource "azuread_service_principal_delegated_permission_grant" "cluster_monitor_msgraph" {
  service_principal_object_id          = azuread_service_principal.cluster_monitor.object_id
  resource_service_principal_object_id = azuread_service_principal.msgraph.object_id
  claim_values                         = ["email", "openid", "profile", "offline_access", "User.Read"]
}

resource "azuread_app_role_assignment" "cluster_monitor_allow_owner" {
  app_role_id         = "00000000-0000-0000-0000-000000000000"
  principal_object_id = var.owner
  resource_object_id  = azuread_service_principal.cluster_monitor.object_id
}

resource "azuread_application_password" "cluster_monitor" {
  application_id = azuread_application.cluster_monitor.id
  display_name   = "Cluster monitor - ${var.environment_name}"
}

resource "azuread_application_pre_authorized" "cluster_monitor_azure_cli" {
  application_id       = azuread_application.cluster_monitor.id
  authorized_client_id = local.azure_cli_client_id
  permission_ids       = [random_uuid.user_impersonation_scope_id.result]
}
