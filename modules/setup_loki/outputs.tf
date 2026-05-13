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

output "openobserve_url" {
  description = "In-cluster base URL of the OpenObserve HTTP API/UI"
  value       = local.openobserve_url
}

output "openobserve_loki_push_url" {
  description = "OpenObserve's Loki-compatible ingest endpoint (used by Alloy to dual-write logs)"
  value       = "${local.openobserve_url}${local.openobserve_loki_push_path}"
}
