output "k8s_namespace" {
  description = "Namespace where pgAdmin and its oauth2-proxy are deployed"
  value       = kubernetes_namespace_v1.pgadmin.metadata[0].name
}

output "hostname" {
  description = "Public hostname where pgAdmin is exposed"
  value       = var.hostname
  sensitive   = true
}

output "admin_email" {
  description = "Login email for the pgAdmin master account (used after passing oauth2-proxy)"
  value       = local.pgadmin_admin_email
  sensitive   = true
}

output "admin_password" {
  description = "Login password for the pgAdmin master account"
  value       = random_password.pgadmin_admin.result
  sensitive   = true
}
