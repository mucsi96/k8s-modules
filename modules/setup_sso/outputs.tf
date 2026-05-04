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
  sensitive   = true
}

output "cluster_admin_service_account_name" {
  value       = kubernetes_service_account_v1.cluster_admin.metadata[0].name
  description = "Name of the cluster-admin ServiceAccount granted to authenticated users"
}

output "cluster_admin_token" {
  value       = kubernetes_secret_v1.cluster_admin_token.data["token"]
  description = "Bearer token for the cluster-admin ServiceAccount"
  sensitive   = true
}
