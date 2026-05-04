data "azuread_client_config" "current" {}

data "azuread_application_published_app_ids" "well_known" {}

resource "azuread_service_principal" "msgraph" {
  client_id    = data.azuread_application_published_app_ids.well_known.result.MicrosoftGraph
  use_existing = true
}

locals {
  auth_hostname = "auth.${var.dns_zone}"
}

resource "azuread_application" "oauth2_proxy" {
  display_name     = "OAuth2 Proxy - ${var.environment_name}"
  sign_in_audience = "AzureADMyOrg"
  owners           = [var.owner]

  web {
    redirect_uris = [
      "https://${local.auth_hostname}/oauth2/callback"
    ]

    implicit_grant {
      access_token_issuance_enabled = false
      id_token_issuance_enabled     = true
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
      id   = azuread_service_principal.msgraph.oauth2_permission_scope_ids["User.Read"]
      type = "Scope"
    }
  }
}

resource "azuread_service_principal" "oauth2_proxy" {
  client_id                    = azuread_application.oauth2_proxy.client_id
  owners                       = [var.owner]
  tags                         = ["WindowsAzureActiveDirectoryIntegratedApp"]
  app_role_assignment_required = true
}

resource "azuread_service_principal_delegated_permission_grant" "oauth2_proxy_msgraph" {
  service_principal_object_id          = azuread_service_principal.oauth2_proxy.object_id
  resource_service_principal_object_id = azuread_service_principal.msgraph.object_id
  claim_values                         = ["email", "openid", "profile", "User.Read"]
}

resource "azuread_app_role_assignment" "allow_owner" {
  app_role_id         = "00000000-0000-0000-0000-000000000000"
  principal_object_id = var.owner
  resource_object_id  = azuread_service_principal.oauth2_proxy.object_id
}

resource "azuread_application_password" "oauth2_proxy" {
  application_id = azuread_application.oauth2_proxy.id
  display_name   = "OAuth2 Proxy - ${var.environment_name}"
}
