locals {
  hostname      = "k8s.${var.dns_zone}"
  headlamp_name = "headlamp"
  headlamp_port = 80
}

resource "kubernetes_namespace_v1" "k8s_dashboard" {
  metadata {
    name = "k8s-dashboard"
  }
}

resource "helm_release" "headlamp" {
  name       = local.headlamp_name
  repository = "https://kubernetes-sigs.github.io/headlamp/"
  chart      = "headlamp"
  version    = var.headlamp_chart_version
  namespace  = kubernetes_namespace_v1.k8s_dashboard.metadata[0].name
  wait       = true
  timeout    = 600

  values = [yamlencode({
    serviceAccount = {
      create = true
    }
    clusterRoleBinding = {
      create          = true
      clusterRoleName = "cluster-admin"
    }
    service = {
      type = "ClusterIP"
      port = local.headlamp_port
    }
    ingress = {
      enabled = false
    }
  })]
}

module "headlamp_oauth2_proxy" {
  source = "../setup_oauth2_proxy"

  name                       = "headlamp"
  namespace                  = kubernetes_namespace_v1.k8s_dashboard.metadata[0].name
  hostname                   = local.hostname
  display_name               = "Headlamp"
  environment_name           = var.environment_name
  owner                      = var.owner
  tenant_id                  = var.tenant_id
  valid_email                = var.valid_email
  oauth2_proxy_chart_version = var.oauth2_proxy_chart_version
  oauth2_proxy_image_version = var.oauth2_proxy_image_version
  upstream_uri               = "http://${helm_release.headlamp.name}.${kubernetes_namespace_v1.k8s_dashboard.metadata[0].name}.svc.cluster.local:${local.headlamp_port}"

  depends_on = [helm_release.headlamp]
}
