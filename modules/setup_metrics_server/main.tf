resource "terraform_data" "wait_for" {
  input = var.wait_for
}

resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = var.metrics_server_chart_version
  namespace  = "kube-system"
  wait       = true
  timeout    = 600

  values = [yamlencode({
    image = {
      tag = var.metrics_server_image_version
    }
    args = [
      "--kubelet-insecure-tls",
      "--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname",
    ]
    # The chart's default request (100m / 200Mi) is sized for large clusters;
    # this single-node cluster's scrape load sits around 3m / 34Mi.
    resources = {
      requests = {
        cpu    = "25m"
        memory = "64Mi"
      }
    }
  })]

  depends_on = [terraform_data.wait_for]
}
