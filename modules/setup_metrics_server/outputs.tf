output "metrics_server_ready" {
  description = "metrics-server Helm release status to ensure it's ready"
  value       = helm_release.metrics_server.status
}
