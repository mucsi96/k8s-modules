output "auth_namespace" {
  value       = kubernetes_namespace_v1.auth.metadata[0].name
  description = "Namespace where the auth service is deployed"
}

output "auth_middleware_name" {
  value       = "auth"
  description = "Name of the Traefik chain middleware that protects routes via oauth2-proxy"
}

output "auth_hostname" {
  value       = local.auth_hostname
  description = "Hostname where oauth2-proxy is exposed"
}
