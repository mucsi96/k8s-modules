output "k8s_namespace" {
  description = "Namespace where pgweb and its oauth2-proxy are deployed"
  value       = kubernetes_namespace_v1.pgweb.metadata[0].name
}

output "hostname" {
  description = "Public hostname where pgweb is exposed"
  value       = var.hostname
  sensitive   = true
}
