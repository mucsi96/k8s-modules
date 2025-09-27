resource "azuread_application" "job" {
  display_name     = var.display_name
  sign_in_audience = "AzureADMyOrg"
  owners           = [var.owner]

  api {
    requested_access_token_version = 2
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

    dynamic "resource_access" {
      for_each = var.api_role_ids

      content {
        id   = resource_access.value
        type = "Role"
      }
    }
  }
}

resource "azuread_service_principal" "job_service_principal" {
  client_id                    = azuread_application.job.client_id
  owners                       = [var.owner]
  tags                         = ["WindowsAzureActiveDirectoryIntegratedApp"]
  app_role_assignment_required = false
}

resource "azuread_application_pre_authorized" "allow_job_to_access_api" {
  application_id       = var.api_id
  authorized_client_id = azuread_application.job.client_id
  permission_ids       = var.api_scope_ids
}

resource "azuread_application_federated_identity_credential" "federated_identity_credential" {
  application_id = azuread_application.job.id
  display_name   = replace(lower(var.display_name), " ", "-")
  description    = var.display_name
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = var.k8s_oidc_issuer_url
  subject        = "system:serviceaccount:${var.k8s_service_account_namespace}:${var.k8s_service_account_name}"
}
