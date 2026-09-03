output "namespace" {
  description = "Namespace where Alloy (pod log collection + Faro receiver) is installed"
  value       = kubernetes_namespace_v1.logging.metadata[0].name
}
