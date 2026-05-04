output "k8s_dashboard_namespace" {
  value       = kubernetes_namespace_v1.headlamp.metadata[0].name
  description = "Namespace where the Kubernetes dashboard (Headlamp) is deployed"
}

output "k8s_dashboard_hostname" {
  value       = local.k8s_dashboard_host
  description = "Hostname where the Kubernetes dashboard (Headlamp) is exposed"
  sensitive   = true
}
