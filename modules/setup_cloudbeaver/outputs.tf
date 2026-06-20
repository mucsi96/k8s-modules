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
  description = "Generated password for the CloudBeaver 'cbadmin' account. Not needed for day-to-day use (oauth2-proxy is the single sign-on gate and the seeded connection is granted to anonymous users); kept only for administrative tasks such as managing users or connections."
  value       = random_password.admin.result
  sensitive   = true
}
