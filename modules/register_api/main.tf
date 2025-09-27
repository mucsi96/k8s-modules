resource "random_uuid" "role_id" {
  for_each = toset(var.roles)
}

resource "random_uuid" "scope_id" {
  for_each = toset(var.scopes)
}

resource "azuread_application" "api" {
  display_name = var.display_name
  owners       = [var.owner]

  dynamic "app_role" {
    for_each = toset(var.roles)

    content {
      allowed_member_types = ["User"]
      description          = "${var.display_name} ${app_role.value} role"
      display_name         = app_role.value
      id                   = random_uuid.role_id[app_role.value].result
      value                = app_role.value
    }
  }

  api {
    requested_access_token_version = 2

    dynamic "oauth2_permission_scope" {
      for_each = toset(var.scopes)

      content {
        admin_consent_description  = "${var.display_name} ${oauth2_permission_scope.value} scope"
        admin_consent_display_name = "${var.display_name} ${oauth2_permission_scope.value} scope"
        id                         = random_uuid.scope_id[oauth2_permission_scope.value].result
        value                      = oauth2_permission_scope.value
      }
    }
  }
}

resource "azuread_application_identifier_uri" "app_uri" {
  application_id = azuread_application.api.id
  identifier_uri = "api://${azuread_application.api.client_id}"
}

resource "azuread_service_principal" "service_principal" {
  client_id                    = azuread_application.api.client_id
  owners                       = [var.owner]
  tags                         = ["WindowsAzureActiveDirectoryIntegratedApp"]
  app_role_assignment_required = false
}

resource "azuread_application_federated_identity_credential" "federated_identity_credential" {
  application_id = azuread_application.api.id
  display_name   = replace(lower(var.display_name), " ", "-")
  description    = var.display_name
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = var.k8s_oidc_issuer_url
  subject        = "system:serviceaccount:${var.k8s_service_account_namespace}:${var.k8s_service_account_name}"
}
