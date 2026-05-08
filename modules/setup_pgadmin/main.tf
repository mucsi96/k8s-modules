locals {
  pgadmin_name        = "pgadmin"
  pgadmin_port        = 80
  pgadmin_admin_email = "admin@${var.hostname}"
}

resource "terraform_data" "wait_for" {
  input = var.wait_for
}

resource "kubernetes_namespace_v1" "pgadmin" {
  metadata {
    name = "pgadmin"
  }

  depends_on = [terraform_data.wait_for]
}

resource "random_password" "pgadmin_admin" {
  length           = 24
  special          = true
  override_special = "-_=+:[]{}"
}

resource "kubernetes_persistent_volume_v1" "pgadmin_pv" {
  metadata {
    name = "pgadmin"
  }

  spec {
    storage_class_name = ""
    access_modes       = ["ReadWriteOnce"]
    capacity = {
      storage = "2Gi"
    }
    persistent_volume_reclaim_policy = "Retain"
    persistent_volume_source {
      host_path {
        path = "/data/pgadmin"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "pgadmin_pvc" {
  metadata {
    name      = "pgadmin"
    namespace = kubernetes_namespace_v1.pgadmin.metadata[0].name
  }

  spec {
    storage_class_name = ""
    access_modes       = ["ReadWriteOnce"]
    volume_name        = kubernetes_persistent_volume_v1.pgadmin_pv.metadata[0].name
    resources {
      requests = {
        storage = "2Gi"
      }
    }
  }
}

resource "kubernetes_secret_v1" "pgadmin_admin" {
  metadata {
    name      = "pgadmin-admin"
    namespace = kubernetes_namespace_v1.pgadmin.metadata[0].name
  }

  data = {
    password = random_password.pgadmin_admin.result
  }
}

resource "helm_release" "pgadmin" {
  name       = local.pgadmin_name
  repository = "https://helm.runix.net"
  chart      = "pgadmin4"
  version    = var.pgadmin_chart_version
  namespace  = kubernetes_namespace_v1.pgadmin.metadata[0].name
  wait       = true
  timeout    = 600

  values = [yamlencode({
    image = {
      tag = var.pgadmin_image_version
    }
    env = {
      email = local.pgadmin_admin_email
    }
    existingSecret = kubernetes_secret_v1.pgadmin_admin.metadata[0].name
    secretKeys = {
      pgadminPasswordKey = "password"
    }
    persistentVolume = {
      enabled       = true
      existingClaim = kubernetes_persistent_volume_claim_v1.pgadmin_pvc.metadata[0].name
    }
    serverDefinitions = {
      enabled      = true
      resourceType = "ConfigMap"
      servers = jsonencode({
        Servers = {
          "1" = {
            Name          = "Postgres"
            Group         = "Servers"
            Host          = var.database.host
            Port          = var.database.port
            MaintenanceDB = var.database.name
            Username      = var.database.username
            SSLMode       = "prefer"
          }
        }
      })
    }
    service = {
      type = "ClusterIP"
      port = local.pgadmin_port
    }
    ingress = {
      enabled = false
    }
  })]
}

module "pgadmin_oauth2_proxy" {
  source = "../setup_oauth2_proxy"

  name                       = local.pgadmin_name
  namespace                  = kubernetes_namespace_v1.pgadmin.metadata[0].name
  client_id                  = var.client_id
  client_secret              = var.client_secret
  tenant_id                  = var.tenant_id
  valid_email                = var.valid_email
  oauth2_proxy_chart_version = var.oauth2_proxy_chart_version
  oauth2_proxy_image_version = var.oauth2_proxy_image_version
  upstream_uri               = "http://${helm_release.pgadmin.name}-pgadmin4.${kubernetes_namespace_v1.pgadmin.metadata[0].name}.svc.cluster.local:${local.pgadmin_port}"
  session_redis              = var.session_redis

  depends_on = [helm_release.pgadmin]
}

resource "kubernetes_manifest" "pgadmin_ingressroute" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "pgadmin"
      namespace = kubernetes_namespace_v1.pgadmin.metadata[0].name
    }
    spec = {
      entryPoints = ["web"]
      routes = [
        {
          match = "Host(`${var.hostname}`)"
          kind  = "Rule"
          services = [{
            name = module.pgadmin_oauth2_proxy.service_name
            port = 80
          }]
        },
      ]
    }
  }

  depends_on = [module.pgadmin_oauth2_proxy]
}
