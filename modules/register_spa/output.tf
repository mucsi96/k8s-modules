output "client_id" {
  value = azuread_application.spa.client_id
}

output "resource_object_id" {
  value = azuread_service_principal.spa_service_principal.object_id
}

output "application_id" {
  value = azuread_application.spa.id
}

output "client_secret" {
  description = "Confidential Web-client credential; null for legacy SPA clients."
  value       = try(azuread_application_password.web[0].value, null)
  sensitive   = true
}
