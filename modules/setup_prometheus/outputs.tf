output "prometheus_namespace" {
  description = "Namespace where the kube-prometheus-stack is deployed"
  value       = kubernetes_namespace_v1.prometheus.metadata[0].name
}

output "kube_prometheus_stack_ready" {
  description = "kube-prometheus-stack Helm release status"
  value       = helm_release.kube_prometheus_stack.status
}

output "prometheus_adapter_ready" {
  description = "prometheus-adapter Helm release status"
  value       = helm_release.prometheus_adapter.status
}

output "blackbox_exporter_ready" {
  description = "prometheus-blackbox-exporter Helm release status"
  value       = helm_release.blackbox_exporter.status
}
