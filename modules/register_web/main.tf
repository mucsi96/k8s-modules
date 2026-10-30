data "azuread_application_published_app_ids" "well_known" {}

resource "azuread_service_principal" "msgraph" {
  client_id    = data.azuread_application_published_app_ids.well_known.result.MicrosoftGraph
  use_existing = true
}

resource "azuread_application" "web" {
  display_name     = var.display_name
  sign_in_audience = "AzureADMyOrg"
  owners           = [var.owner]

  api {
    requested_access_token_version = 2
  }

  web {
    redirect_uris = var.redirect_uris

    implicit_grant {
      access_token_issuance_enabled = false
      id_token_issuance_enabled     = false
    }
  }

  required_resource_access {
    resource_app_id = data.azuread_application_published_app_ids.well_known.result.MicrosoftGraph

    dynamic "resource_access" {
      for_each = toset(["openid", "profile", "email", "offline_access"])
      content {
        id   = azuread_service_principal.msgraph.oauth2_permission_scope_ids[resource_access.value]
        type = "Scope"
      }
    }
  }

  dynamic "required_resource_access" {
    for_each = var.api_access == null ? [] : [var.api_access]
    content {
      resource_app_id = required_resource_access.value.client_id
      resource_access {
        id   = required_resource_access.value.scope_id
        type = "Scope"
      }
    }
  }
}

resource "azuread_service_principal" "web" {
  client_id                    = azuread_application.web.client_id
  owners                       = [var.owner]
  tags                         = ["WindowsAzureActiveDirectoryIntegratedApp"]
  app_role_assignment_required = true
}

resource "azuread_application_pre_authorized" "api" {
  count                = var.api_access == null ? 0 : 1
  application_id       = var.api_access.application_id
  authorized_client_id = azuread_application.web.client_id
  permission_ids       = [var.api_access.scope_id]
}

resource "azuread_service_principal_delegated_permission_grant" "oidc" {
  service_principal_object_id          = azuread_service_principal.web.object_id
  resource_service_principal_object_id = azuread_service_principal.msgraph.object_id
  claim_values                         = ["openid", "profile", "email", "offline_access"]
}

resource "azuread_application_password" "web" {
  application_id = azuread_application.web.id
  display_name   = "oauth2-proxy"
}

resource "azuread_app_role_assignment" "users" {
  for_each            = setunion(toset([var.owner]), var.allowed_user_ids)
  app_role_id         = "00000000-0000-0000-0000-000000000000"
  principal_object_id = each.value
  resource_object_id  = azuread_service_principal.web.object_id
}
