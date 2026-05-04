output "namespace" {
  description = "Namespace where oauth2-proxy is deployed"
  value       = kubernetes_namespace_v1.this.metadata[0].name
}

output "service_name" {
  description = "Service name of the oauth2-proxy"
  value       = local.release_name
}

output "service_port" {
  description = "Service port of the oauth2-proxy"
  value       = 80
}

output "client_id" {
  description = "Entra ID client ID used by oauth2-proxy"
  value       = module.oauth_app.client_id
}
