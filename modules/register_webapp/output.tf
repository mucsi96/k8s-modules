output "client_id" {
  value = azuread_application.webapp.client_id
}

output "client_secret" {
  value     = azuread_application_password.webapp_password.value
  sensitive = true
}

output "resource_object_id" {
  value = azuread_service_principal.webapp_service_principal.object_id
}

output "application_id" {
  value = azuread_application.webapp.id
}
