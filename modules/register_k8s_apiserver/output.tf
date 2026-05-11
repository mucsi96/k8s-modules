output "client_id" {
  description = "Entra application (client) ID. Pass as kube-apiserver --oidc-client-id and as kubelogin --server-id."
  value       = azuread_application.apiserver.client_id
}

output "application_id_uri" {
  description = "api://<client_id> URI exposed by the apiserver resource app."
  value       = azuread_application_identifier_uri.apiserver.identifier_uri
}

output "service_principal_object_id" {
  description = "Object ID of the apiserver service principal (useful for diagnostics)."
  value       = azuread_service_principal.apiserver.object_id
}
