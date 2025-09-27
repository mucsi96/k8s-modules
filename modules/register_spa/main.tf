data "azuread_application_published_app_ids" "well_known" {}

resource "azuread_service_principal" "msgraph" {
  client_id    = data.azuread_application_published_app_ids.well_known.result.MicrosoftGraph
  use_existing = true
}

resource "azuread_application" "spa" {
  display_name     = var.display_name
  sign_in_audience = "AzureADMyOrg"
  owners           = [var.owner]

  api {
    requested_access_token_version = 2
  }

  single_page_application {
    redirect_uris = var.redirect_uris
  }

  required_resource_access {
    resource_app_id = data.azuread_application_published_app_ids.well_known.result.MicrosoftGraph

    resource_access {
      id   = azuread_service_principal.msgraph.oauth2_permission_scope_ids["openid"]
      type = "Scope"
    }

    resource_access {
      id   = azuread_service_principal.msgraph.oauth2_permission_scope_ids["User.Read"]
      type = "Scope"
    }
  }

  required_resource_access {
    resource_app_id = var.api_client_id

    dynamic "resource_access" {
      for_each = var.api_scope_ids

      content {
        id   = resource_access.value
        type = "Scope"
      }
    }
  }
}

resource "azuread_service_principal" "spa_service_principal" {
  client_id                    = azuread_application.spa.client_id
  owners                       = [var.owner]
  tags                         = ["WindowsAzureActiveDirectoryIntegratedApp"]
  app_role_assignment_required = false
}

resource "azuread_application_pre_authorized" "allow_spa_to_access_api" {
  application_id       = var.api_id
  authorized_client_id = azuread_application.spa.client_id
  permission_ids       = var.api_scope_ids
}

resource "azuread_service_principal_delegated_permission_grant" "allow_spa_to_access_msgraph_user_profile" {
  service_principal_object_id          = azuread_service_principal.spa_service_principal.object_id
  resource_service_principal_object_id = azuread_service_principal.msgraph.object_id
  claim_values                         = ["openid", "User.Read"]
}
