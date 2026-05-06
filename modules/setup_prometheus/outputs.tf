output "prometheus_namespace" {
  description = "Namespace where Prometheus is deployed"
  value       = kubernetes_namespace_v1.prometheus.metadata[0].name
}

output "prometheus_ready" {
  description = "Prometheus Helm release status to ensure it's ready"
  value       = helm_release.prometheus.status
}
