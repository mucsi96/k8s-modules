output "client_id" {
  description = "The application (client) ID"
  value       = azuread_application.this.client_id
}

output "client_secret" {
  description = "The application client secret"
  value       = azuread_application_password.this.value
  sensitive   = true
}

output "application_id" {
  description = "The Entra ID application object ID"
  value       = azuread_application.this.id
}

output "service_principal_object_id" {
  description = "The Entra ID service principal object ID"
  value       = azuread_service_principal.this.object_id
}
