output "namespace" {
  description = "Namespace where the Faro receiver is installed"
  value       = var.k8s_namespace
}

output "endpoint_url" {
  description = "Public Faro collector URL. Point the Faro Web SDK's url option at <endpoint_url>/collect."
  value       = "https://${var.hostname}"
}

output "faro_ready" {
  description = "Faro Alloy Helm release status, exposed so dependent modules can gate on readiness."
  value       = helm_release.alloy.status
}
