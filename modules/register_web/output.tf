output "client_id" {
  value = azuread_application.web.client_id
}

output "client_secret" {
  value     = azuread_application_password.web.value
  sensitive = true
}
