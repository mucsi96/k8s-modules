output "k8s_user_config" {
  value     = <<EOT
apiVersion: v1
kind: Config
clusters:
  - name: cluster
    cluster:
      server: ${var.k8s_host}
      certificate-authority-data: ${base64encode(var.k8s_cluster_ca_certificate)}
users:
  - name: user
    user:
      token: ${kubernetes_secret_v1.service_account_token_secret.data.token}
contexts:
  - name: default
    context:
      cluster: cluster
      name: default
      user: user
      namespace: ${var.k8s_namespace}
current-context: default
EOT
  sensitive = true
}

output "k8s_namespace" {
  value = kubernetes_namespace_v1.namespace.metadata[0].name
}
