locals {
  headlamp_name = "headlamp"
  headlamp_port = 80
}

resource "terraform_data" "wait_for" {
  input = var.wait_for
}

resource "kubernetes_namespace_v1" "k8s_dashboard" {
  metadata {
    name = "k8s-dashboard"
  }

  depends_on = [terraform_data.wait_for]
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
    image = {
      tag = var.headlamp_image_version
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
      port = local.headlamp_port
    }
    ingress = {
      enabled = false
    }
  })]
}

module "headlamp_session_redis" {
  source = "../setup_redis"

  name      = "headlamp"
  namespace = kubernetes_namespace_v1.k8s_dashboard.metadata[0].name
}

module "headlamp_oauth2_proxy" {
  source = "../setup_oauth2_proxy"

  name                       = "headlamp"
  namespace                  = kubernetes_namespace_v1.k8s_dashboard.metadata[0].name
  client_id                  = var.client_id
  client_secret              = var.client_secret
  tenant_id                  = var.tenant_id
  valid_email                = var.valid_email
  oauth2_proxy_chart_version = var.oauth2_proxy_chart_version
  oauth2_proxy_image_version = var.oauth2_proxy_image_version
  upstream_uri               = "http://${helm_release.headlamp.name}.${kubernetes_namespace_v1.k8s_dashboard.metadata[0].name}.svc.cluster.local:${local.headlamp_port}"

  session_redis = {
    connection_url = module.headlamp_session_redis.connection_url
    password       = module.headlamp_session_redis.password
  }

  inject_request_headers = [{
    name = "Authorization"
    values = [{
      claim  = "id_token"
      prefix = "Bearer "
    }]
  }]

  depends_on = [helm_release.headlamp]
}

resource "kubernetes_cluster_role_binding_v1" "headlamp_user" {
  metadata {
    name = "headlamp-user"
  }

  subject {
    kind      = "User"
    name      = var.valid_email
    api_group = "rbac.authorization.k8s.io"
  }

  role_ref {
    kind      = "ClusterRole"
    name      = "cluster-admin"
    api_group = "rbac.authorization.k8s.io"
  }
}

resource "kubernetes_manifest" "headlamp_ingressroute" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "headlamp"
      namespace = kubernetes_namespace_v1.k8s_dashboard.metadata[0].name
    }
    spec = {
      entryPoints = ["web"]
      routes = [
        {
          match = "Host(`${var.hostname}`)"
          kind  = "Rule"
          services = [{
            name = module.headlamp_oauth2_proxy.service_name
            port = 80
          }]
        },
      ]
    }
  }

  depends_on = [module.headlamp_oauth2_proxy]
}
