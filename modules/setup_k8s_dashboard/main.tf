locals {
  dashboard_hostname = "dashboard.${var.dns_zone}"
}

resource "kubernetes_namespace_v1" "dashboard" {
  metadata {
    name = "kubernetes-dashboard"
  }
}

resource "helm_release" "kubernetes_dashboard" {
  name       = "kubernetes-dashboard"
  repository = "https://kubernetes.github.io/dashboard/"
  chart      = "kubernetes-dashboard"
  version    = var.dashboard_chart_version
  namespace  = kubernetes_namespace_v1.dashboard.metadata[0].name
  wait       = true
  timeout    = 600

  #https://github.com/kubernetes/dashboard/blob/master/charts/kubernetes-dashboard/values.yaml
  values = [yamlencode({
    kong = {
      proxy = {
        type = "ClusterIP"
        http = {
          enabled = true
        }
      }
    }
  })]
}
