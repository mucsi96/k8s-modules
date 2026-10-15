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

  dynamic "single_page_application" {
    for_each = length(var.web_redirect_uris) == 0 || var.retain_spa_redirects ? [true] : []
    content {
      redirect_uris = var.redirect_uris
    }
  }

  dynamic "web" {
    for_each = length(var.web_redirect_uris) > 0 ? [true] : []
    content {
      redirect_uris = var.web_redirect_uris
    }
  }

  required_resource_access {
    resource_app_id = data.azuread_application_published_app_ids.well_known.result.MicrosoftGraph

    dynamic "resource_access" {
      for_each = toset(length(var.web_redirect_uris) > 0 ? ["openid", "profile", "email", "offline_access"] : ["openid", "User.Read"])
      content {
        id   = azuread_service_principal.msgraph.oauth2_permission_scope_ids[resource_access.value]
        type = "Scope"
      }
    }
  }

  required_resource_access {
    resource_app_id = var.api_client_id

    resource_access {
      id   = var.api_scope_id
      type = "Scope"
    }
  }
}

resource "azuread_service_principal" "spa_service_principal" {
  client_id                    = azuread_application.spa.client_id
  owners                       = [var.owner]
  tags                         = ["WindowsAzureActiveDirectoryIntegratedApp"]
  app_role_assignment_required = length(var.web_redirect_uris) > 0
}

resource "azuread_application_pre_authorized" "allow_spa_to_access_api" {
  application_id       = var.api_id
  authorized_client_id = azuread_application.spa.client_id
  permission_ids       = [var.api_scope_id]
}

resource "azuread_service_principal_delegated_permission_grant" "allow_spa_to_access_msgraph_user_profile" {
  service_principal_object_id          = azuread_service_principal.spa_service_principal.object_id
  resource_service_principal_object_id = azuread_service_principal.msgraph.object_id
  claim_values                         = length(var.web_redirect_uris) > 0 ? ["openid", "profile", "email", "offline_access"] : ["openid", "User.Read"]
}

resource "azuread_application_password" "web" {
  count          = length(var.web_redirect_uris) > 0 ? 1 : 0
  application_id = azuread_application.spa.id
  display_name   = "oauth2-proxy"
}

resource "azuread_app_role_assignment" "web_users" {
  for_each            = length(var.web_redirect_uris) > 0 ? setunion(toset([var.owner]), var.allowed_user_ids) : toset([])
  app_role_id         = "00000000-0000-0000-0000-000000000000"
  principal_object_id = each.value
  resource_object_id  = azuread_service_principal.spa_service_principal.object_id
}
