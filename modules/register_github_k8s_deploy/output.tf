output "client_id" {
  description = "Entra application (client) ID for AZURE_CLIENT_ID in the GitHub Actions workflow."
  value       = azuread_application.deploy.client_id
}

output "service_principal_object_id" {
  description = "Object ID of the service principal. Use this as the RBAC subject (User <oid>) in the ClusterRoleBinding."
  value       = azuread_service_principal.deploy.object_id
}
