output "client_id" {
  value = azuread_application.job.client_id
}

output "resource_object_id" {
  value = azuread_service_principal.job_service_principal.object_id
}

output "application_id" {
  value = azuread_application.job.id
}
