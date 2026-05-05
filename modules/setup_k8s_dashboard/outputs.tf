output "k8s_namespace" {
  description = "Namespace where Headlamp and its oauth2-proxy are deployed"
  value       = kubernetes_namespace_v1.k8s_dashboard.metadata[0].name
}

output "hostname" {
  description = "Public hostname where the Headlamp dashboard is exposed"
  value       = var.hostname
  sensitive   = true
}
