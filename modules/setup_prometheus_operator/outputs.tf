output "namespace" {
  description = "Namespace where the VictoriaMetrics stack is installed"
  value       = kubernetes_namespace_v1.monitoring.metadata[0].name
}

output "victoria_metrics_k8s_stack_ready" {
  description = "victoria-metrics-k8s-stack Helm release status to ensure it's ready"
  value       = helm_release.victoria_metrics_k8s_stack.status
}

output "victoria_logs_url" {
  description = "In-cluster base URL of the VLSingle HTTP API (9428). Log shippers append the Loki-compatible /insert/loki/api/v1/push path to it."
  value       = "http://vlsingle-${local.release_name}.${kubernetes_namespace_v1.monitoring.metadata[0].name}.svc.cluster.local:9428"
}
