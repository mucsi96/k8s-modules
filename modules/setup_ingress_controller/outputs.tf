output "ingress_controller_namespace" {
  value       = kubernetes_namespace_v1.traefik.metadata[0].name
  description = "Namespace containing the ingress controller."
}

output "ingress_controller_ready" {
  value       = helm_release.traefik.status
  description = "Ingress controller readiness token for downstream ordering."
}
