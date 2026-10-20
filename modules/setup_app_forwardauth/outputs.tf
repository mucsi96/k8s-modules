output "deployment_config" {
  description = "Non-secret proxy reference passed by deployment to client/API charts, which own their authentication policies."
  value = {
    release_name = helm_release.auth.name
    auth = {
      proxyService = local.release_name
      proxyPort    = 80
      mode         = var.mode
    }
  }
}
