output "k8s_user_config" {
  value     = <<EOT
apiVersion: v1
kind: Config
clusters:
  - name: cluster
    cluster:
      server: ${yamldecode(data.azurerm_kubernetes_cluster.kubernetes_cluster.kube_config_raw).clusters[0].cluster.server}
      certificate-authority-data: ${yamldecode(data.azurerm_kubernetes_cluster.kubernetes_cluster.kube_config_raw).clusters[0].cluster.certificate-authority-data}
users:
  - name: user
    user:
      token: ${kubernetes_secret.service_account_token_secret.data.token}
contexts:
  - name: default
    context:
      cluster: cluster
      name: default
      user: user
current-context: default
EOT
  sensitive = true
}

output "k8s_namespace" {
  value = kubernetes_namespace.namespace.metadata[0].name
}
