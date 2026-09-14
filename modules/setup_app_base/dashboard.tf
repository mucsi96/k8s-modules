output "dashboard_app" {
  description = "Non-secret application descriptor for the fleet dashboard."
  value = {
    name       = title(replace(var.app_name, "-", " "))
    namespace  = module.create_namespace.k8s_namespace
    repository = "mucsi96/${var.github_repository}"
    # Hostnames originate in Key Vault but are public routing metadata.
    url = "https://${nonsensitive(var.app_hostname)}"
  }
}
