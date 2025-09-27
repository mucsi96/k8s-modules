output "client_id" {
  value = azuread_application.api.client_id
}

output "roles_ids" {
  value = { for role in var.roles : role => random_uuid.role_id[role].result }
}

output "scope_ids" {
  value = { for scope in var.scopes : scope => random_uuid.scope_id[scope].result }
}

output "resource_object_id" {
  value = azuread_service_principal.service_principal.object_id
}

output "application_id" {
  value = azuread_application.api.id
}
