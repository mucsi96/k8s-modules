data "azuread_application_published_app_ids" "well_known" {}

resource "azuread_service_principal" "msgraph" {
  client_id    = data.azuread_application_published_app_ids.well_known.result.MicrosoftGraph
  use_existing = true
}

resource "azuread_application" "webapp" {
  display_name     = var.display_name
  sign_in_audience = "AzureADMyOrg"
  owners           = [var.owner]

  web {
    redirect_uris = var.redirect_uris

    implicit_grant {
      access_token_issuance_enabled = false
      id_token_issuance_enabled     = true
    }
  }

  required_resource_access {
    resource_app_id = data.azuread_application_published_app_ids.well_known.result.MicrosoftGraph

    resource_access {
      id   = azuread_service_principal.msgraph.oauth2_permission_scope_ids["openid"]
      type = "Scope"
    }

    resource_access {
      id   = azuread_service_principal.msgraph.oauth2_permission_scope_ids["profile"]
      type = "Scope"
    }

    resource_access {
      id   = azuread_service_principal.msgraph.oauth2_permission_scope_ids["email"]
      type = "Scope"
    }
  }
}

resource "azuread_service_principal" "webapp_service_principal" {
  client_id                    = azuread_application.webapp.client_id
  owners                       = [var.owner]
  tags                         = ["WindowsAzureActiveDirectoryIntegratedApp"]
  app_role_assignment_required = true
}

resource "azuread_service_principal_delegated_permission_grant" "allow_webapp_to_access_msgraph_user_profile" {
  service_principal_object_id          = azuread_service_principal.webapp_service_principal.object_id
  resource_service_principal_object_id = azuread_service_principal.msgraph.object_id
  claim_values                         = ["openid", "profile", "email"]
}

resource "azuread_app_role_assignment" "allow_owner" {
  app_role_id         = "00000000-0000-0000-0000-000000000000"
  principal_object_id = var.owner
  resource_object_id  = azuread_service_principal.webapp_service_principal.object_id
}

resource "azuread_application_password" "webapp_password" {
  application_id = azuread_application.webapp.id
  display_name   = var.display_name
}
