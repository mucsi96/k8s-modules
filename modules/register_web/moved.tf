# Preserve resource identities after the owning environment moves the old
# registration module into register_web (see README.md).
moved {
  from = azuread_application.spa
  to   = azuread_application.web
}

moved {
  from = azuread_service_principal.spa_service_principal
  to   = azuread_service_principal.web
}

moved {
  from = azuread_application_pre_authorized.allow_spa_to_access_api
  to   = azuread_application_pre_authorized.api[0]
}

moved {
  from = azuread_service_principal_delegated_permission_grant.allow_spa_to_access_msgraph_user_profile
  to   = azuread_service_principal_delegated_permission_grant.oidc
}

moved {
  from = azuread_application_password.web[0]
  to   = azuread_application_password.web
}

moved {
  from = azuread_app_role_assignment.web_users
  to   = azuread_app_role_assignment.users
}
