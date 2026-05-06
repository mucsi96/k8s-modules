output "client_id" {
  value = azuread_application.puller.client_id
}

output "service_principal_object_id" {
  value = azuread_service_principal.puller.object_id
}
