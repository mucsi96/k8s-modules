output "kubernetes_dashboard_namespace" {
  value       = kubernetes_namespace_v1.kubernetes_dashboard.metadata[0].name
  description = "Namespace where the Kubernetes Dashboard is deployed"
}

output "kubernetes_dashboard_url" {
  value       = "https://${local.dashboard_host}"
  description = "Public URL of the Kubernetes Dashboard"
}
