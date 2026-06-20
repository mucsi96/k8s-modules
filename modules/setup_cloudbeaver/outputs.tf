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
  description = "Generated password for the CloudBeaver 'cbadmin' account. Anonymous access is disabled, so you sign in with cbadmin (after passing oauth2-proxy) to reach the seeded database connection. Retrieve with: terraform output -raw <module>_admin_password."
  value       = random_password.admin.result
  sensitive   = true
}
