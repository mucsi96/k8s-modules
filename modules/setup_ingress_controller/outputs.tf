output "ingress_controller_namespace" {
  value       = local.ingress_controller_namespace
  description = "Namespace containing the k3s-packaged Traefik controller."
}

output "gateway_parent_ref" {
  description = "Parent reference for HTTPRoutes using the shared Gateway."
  value = {
    name         = local.gateway_name
    namespace    = local.gateway_namespace
    section_name = local.gateway_listener_name
  }
}

output "ingress_controller_ready" {
  value       = terraform_data.gateway_ready.id
  description = "Gateway UID emitted only after bundled Traefik reports it Accepted and Programmed."
}
