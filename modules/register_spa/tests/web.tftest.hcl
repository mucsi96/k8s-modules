mock_provider "azuread" {
  mock_data "azuread_application_published_app_ids" {
    defaults = {
      result = { MicrosoftGraph = "00000003-0000-0000-c000-000000000000" }
    }
  }
  mock_resource "azuread_service_principal" {
    defaults = {
      object_id = "10000000-0000-0000-0000-000000000000"
      oauth2_permission_scope_ids = {
        openid         = "20000000-0000-0000-0000-000000000001"
        profile        = "20000000-0000-0000-0000-000000000002"
        email          = "20000000-0000-0000-0000-000000000003"
        offline_access = "20000000-0000-0000-0000-000000000004"
        "User.Read"    = "20000000-0000-0000-0000-000000000005"
      }
    }
  }
}

variables {
  owner         = "30000000-0000-0000-0000-000000000001"
  display_name  = "Hello"
  redirect_uris = ["https://hello.example.test/"]
  api_client_id = "40000000-0000-0000-0000-000000000001"
  api_id        = "/applications/40000000-0000-0000-0000-000000000002"
  api_scope_id  = "40000000-0000-0000-0000-000000000003"
}

run "legacy_spa_contract" {
  command = plan
  assert {
    condition     = length(azuread_application.spa.single_page_application) == 1 && length(azuread_application.spa.web) == 0
    error_message = "Existing callers must retain their SPA redirect type."
  }
  assert {
    condition     = !azuread_service_principal.spa_service_principal.app_role_assignment_required && length(azuread_application_password.web) == 0
    error_message = "Existing callers must not unexpectedly acquire confidential-client requirements."
  }
}

run "web_client_preserves_api_boundary_and_assignments" {
  command = plan
  variables {
    web_redirect_uris = ["https://hello.example.test/oauth2/callback"]
    allowed_user_ids  = ["30000000-0000-0000-0000-000000000002"]
  }
  assert {
    condition     = length(azuread_application.spa.single_page_application) == 0 && length(azuread_application.spa.web) == 1
    error_message = "Migration must replace the SPA redirect type in the existing application resource."
  }
  assert {
    condition     = azuread_service_principal.spa_service_principal.app_role_assignment_required && length(azuread_app_role_assignment.web_users) == 2
    error_message = "Web login must require owner/household assignments."
  }
  assert {
    condition     = azuread_application_pre_authorized.allow_spa_to_access_api.permission_ids == toset([var.api_scope_id])
    error_message = "The app-specific API scope/preauthorization must survive migration."
  }
  assert {
    condition     = !contains(azuread_service_principal_delegated_permission_grant.allow_spa_to_access_msgraph_user_profile.claim_values, "User.Read")
    error_message = "Web clients must not request a Graph access token instead of their API token."
  }
}

run "preprovision_without_breaking_old_clients" {
  command = plan
  variables {
    web_redirect_uris    = ["https://hello.example.test/oauth2/callback"]
    retain_spa_redirects = true
  }
  assert {
    condition     = length(azuread_application.spa.single_page_application) == 1 && length(azuread_application.spa.web) == 1
    error_message = "Preprovisioning must keep existing browser redirects until the cookie-auth build is deployed."
  }
}
