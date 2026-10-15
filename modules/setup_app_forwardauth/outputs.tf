output "document_middleware" {
  value = "${helm_release.auth.name}-document"
}

output "api_middleware" {
  value = "${helm_release.auth.name}-api"
}

output "route_filters_config_map" {
  description = "Non-secret JSON HTTPRoute filters, consumed by app deployment jobs."
  value       = "${helm_release.auth.name}-route-filters"
}
