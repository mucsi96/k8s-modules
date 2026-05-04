output "dashboard_namespace" {
  value       = kubernetes_namespace_v1.dashboard.metadata[0].name
  description = "Namespace where the Kubernetes dashboard is deployed"
}

output "dashboard_hostname" {
  value       = local.dashboard_hostname
  description = "Hostname where the Kubernetes dashboard is exposed"
  sensitive   = true
}
