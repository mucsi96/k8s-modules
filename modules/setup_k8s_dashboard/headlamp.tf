locals {
  k8s_dashboard_host = "k8s.${var.dns_zone}"
}

resource "kubernetes_namespace_v1" "headlamp" {
  metadata {
    name = "headlamp"
  }
}

resource "helm_release" "headlamp" {
  name       = "headlamp"
  repository = "https://headlamp-k8s.github.io/headlamp/"
  chart      = "headlamp"
  version    = var.headlamp_chart_version
  namespace  = kubernetes_namespace_v1.headlamp.metadata[0].name
  wait       = true
  timeout    = 600

  #https://github.com/headlamp-k8s/headlamp/blob/main/charts/headlamp/values.yaml
  values = [yamlencode({
    config = {
      inCluster = true
      baseURL   = ""
    }
    serviceAccount = {
      create = true
    }
    clusterRoleBinding = {
      create          = true
      clusterRoleName = "cluster-admin"
    }
    service = {
      type = "ClusterIP"
      port = 80
    }
    ingress = {
      enabled = false
    }
  })]
}

resource "kubernetes_manifest" "headlamp_ingressroute" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "headlamp"
      namespace = kubernetes_namespace_v1.headlamp.metadata[0].name
    }
    spec = {
      entryPoints = ["web"]
      routes = [{
        match = "Host(`${local.k8s_dashboard_host}`)"
        kind  = "Rule"
        middlewares = [
          {
            name      = var.auth_middleware_name
            namespace = var.auth_middleware_namespace
          },
        ]
        services = [{
          name = "headlamp"
          port = 80
        }]
      }]
    }
  }

  depends_on = [helm_release.headlamp]
}
