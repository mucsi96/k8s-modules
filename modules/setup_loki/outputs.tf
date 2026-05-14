output "namespace" {
  description = "Namespace where Loki and Alloy are installed"
  value       = kubernetes_namespace_v1.logging.metadata[0].name
}

output "loki_url" {
  description = "In-cluster base URL of the Loki HTTP API (push, query)"
  value       = local.loki_url
}

output "loki_ready" {
  description = "Loki Helm release status, exposed so dependent modules can gate on readiness"
  value       = helm_release.loki.status
}

output "parseable_url" {
  description = "In-cluster base URL of the Parseable HTTP API/UI"
  value       = local.parseable_url
}
