output "namespace" {
  description = "Namespace where Alloy (pod log collection + Faro receiver) is installed"
  value       = kubernetes_namespace_v1.logging.metadata[0].name
}

output "faro_client_path" {
  description = "Same-origin telemetry path used to construct frontend collector URLs."
  value       = var.faro_client_path
}
