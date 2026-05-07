output "namespace" {
  description = "Namespace where the Prometheus Operator stack is installed"
  value       = kubernetes_namespace_v1.monitoring.metadata[0].name
}

output "kube_prometheus_stack_ready" {
  description = "kube-prometheus-stack Helm release status to ensure it's ready"
  value       = helm_release.kube_prometheus_stack.status
}
