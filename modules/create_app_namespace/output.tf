output "k8s_namespace" {
  value = kubernetes_namespace_v1.namespace.metadata[0].name
}
