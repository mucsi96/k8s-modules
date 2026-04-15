output "url" {
  value = "ws://${local.app_name}.${local.k8s_namespace}:${local.port}"
}
