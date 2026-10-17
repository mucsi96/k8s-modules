output "deployment_config" {
  description = "Auth configuration consumed by app deployment via Key Vault, or directly by Terraform-managed service HTTPRoutes."
  value = merge({
    release_name = helm_release.auth.name
    route_filters = {
      for target in(var.mode == "api-token" ? ["api"] : ["document", "api"]) :
      target => jsondecode(data.kubernetes_config_map_v1.route_filters.data[target])
    }
    }, var.mode == "api-token" ? {
    session_url = "http://${helm_release.auth.name}.${var.namespace}.svc.cluster.local:80/oauth2/auth"
    sign_in_url = "https://${var.hostname}/oauth2/start"
  } : {})
}
