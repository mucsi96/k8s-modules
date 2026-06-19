output "k8s_namespace" {
  description = "Namespace where CloudBeaver and its oauth2-proxy are deployed"
  value       = kubernetes_namespace_v1.cloudbeaver.metadata[0].name
}

output "hostname" {
  description = "Public hostname where CloudBeaver is exposed"
  value       = var.hostname
  sensitive   = true
}

output "admin_password" {
  description = "Generated CloudBeaver administrator password. Access is already gated by oauth2-proxy and anonymous access is enabled, so these credentials are only needed for administrative tasks (managing users, connections, etc.)."
  value       = random_password.admin.result
  sensitive   = true
}
