data "azuread_client_config" "current" {}

data "azuread_application_published_app_ids" "well_known" {}

resource "azuread_service_principal" "msgraph" {
  client_id    = data.azuread_application_published_app_ids.well_known.result.MicrosoftGraph
  use_existing = true
}

resource "azuread_application" "cloudflare_sso" {
  display_name     = "Cloudflare SSO - ${var.resource_group_name}"
  sign_in_audience = "AzureADMyOrg"
  owners           = [data.azuread_client_config.current.object_id]

  web {
    redirect_uris = [
      "https://${var.cloudflare_team_domain}/cdn-cgi/access/callback"
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
      id   = azuread_service_principal.msgraph.oauth2_permission_scope_ids["offline_access"]
      type = "Scope"
    }

    resource_access {
      id   = azuread_service_principal.msgraph.oauth2_permission_scope_ids["openid"]
      type = "Scope"
    }

    resource_access {
      id   = azuread_service_principal.msgraph.oauth2_permission_scope_ids["User.Read"]
      type = "Scope"
    }
  }
}

resource "azuread_service_principal" "cloudflare_sso" {
  client_id                    = azuread_application.cloudflare_sso.client_id
  owners                       = [data.azuread_client_config.current.object_id]
  tags                         = ["WindowsAzureActiveDirectoryIntegratedApp"]
  app_role_assignment_required = false
}

resource "azuread_application_password" "cloudflare_sso" {
  application_id = azuread_application.cloudflare_sso.id
  display_name   = "Cloudflare SSO - ${var.resource_group_name}"
}

resource "cloudflare_zero_trust_access_identity_provider" "entra_id" {
  account_id = var.cloudflare_account_id
  name       = "Microsoft Entra ID - ${var.resource_group_name}"
  type       = "azureAD"

  config = {
    client_id     = azuread_application.cloudflare_sso.client_id
    client_secret = azuread_application_password.cloudflare_sso.value
    directory_id  = data.azuread_client_config.current.tenant_id
  }
}

resource "cloudflare_zero_trust_access_policy" "cloudflare_sso" {
  account_id = var.cloudflare_account_id
  name       = "Allow Entra ID Users - ${var.resource_group_name}"
  decision   = "allow"

  include = [{
    email = {
      email = var.letsencrypt_email
    }
  }]
}
