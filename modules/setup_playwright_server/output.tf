output "url" {
  value = "ws://${local.app_name}.${var.k8s_namespace}:${local.port}"
}
