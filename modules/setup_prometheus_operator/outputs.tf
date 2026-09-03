output "namespace" {
  description = "Namespace where the VictoriaMetrics stack is installed"
  value       = kubernetes_namespace_v1.monitoring.metadata[0].name
}

output "victoria_metrics_k8s_stack_ready" {
  description = "victoria-metrics-k8s-stack Helm release status to ensure it's ready"
  value       = helm_release.victoria_metrics_k8s_stack.status
}
