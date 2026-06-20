locals {
  cloudbeaver_name = "cloudbeaver"
  cloudbeaver_port = 8978

  # Pre-provisioned global connection. CloudBeaver imports
  # initial-data-sources.conf on first start and persists it into the workspace,
  # so the Postgres database shows up ready to browse and edit (inline data grid)
  # without anyone having to configure a connection through the UI. Credentials
  # are embedded here and encrypted into the workspace on first connect.
  datasources = {
    connections = {
      "${var.database.name}" = {
        provider        = "postgresql"
        driver          = "postgres-jdbc"
        name            = var.database.name
        "save-password" = true
        configuration = {
          host                = var.database.host
          port                = tostring(var.database.port)
          database            = var.database.name
          url                 = "jdbc:postgresql://${var.database.host}:${var.database.port}/${var.database.name}"
          configurationType   = "MANUAL"
          type                = "dev"
          closeIdleConnection = true
          "auth-model"        = "native"
          "auth-properties" = {
            name     = var.database.username
            password = var.database.password
          }
        }
      }
    }
  }
}

resource "random_password" "admin" {
  length  = 32
  special = false
}

resource "terraform_data" "wait_for" {
  input = var.wait_for
}

resource "kubernetes_namespace_v1" "cloudbeaver" {
  metadata {
    name = local.cloudbeaver_name
  }

  depends_on = [terraform_data.wait_for]
}

# CloudBeaver keeps its server config, registered connections and saved
# credentials under the workspace directory, so it must survive pod restarts.
resource "kubernetes_persistent_volume_v1" "cloudbeaver" {
  metadata {
    name = local.cloudbeaver_name
  }

  spec {
    # MicroK8s enables the hostpath-storage addon, which registers a *default*
    # StorageClass (microk8s-hostpath). The Terraform kubernetes provider drops
    # storage_class_name = "" on a PVC (the attribute is Optional+Computed), so
    # the DefaultStorageClass admission controller would inject that default into
    # the claim while this static PV stays empty -> "storageClassName does not
    # match" and the claim never binds. Pinning both sides to the same explicit,
    # non-default class name keeps them matched and stops the injection. No
    # StorageClass object is required: the claim is pre-bound via volume_name, so
    # no dynamic provisioner is ever consulted.
    storage_class_name = "manual"
    access_modes       = ["ReadWriteOnce"]
    capacity = {
      storage = "1Gi"
    }
    persistent_volume_reclaim_policy = "Retain"
    persistent_volume_source {
      host_path {
        path = "/data/cloudbeaver"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "cloudbeaver" {
  metadata {
    name      = local.cloudbeaver_name
    namespace = kubernetes_namespace_v1.cloudbeaver.metadata[0].name
  }

  spec {
    # Must match the PV's storage_class_name (see the PV above) so the claim
    # binds to it instead of triggering the MicroK8s default StorageClass.
    storage_class_name = "manual"
    access_modes       = ["ReadWriteOnce"]
    volume_name        = kubernetes_persistent_volume_v1.cloudbeaver.metadata[0].name
    resources {
      requests = {
        storage = "1Gi"
      }
    }
  }
}

resource "kubernetes_secret_v1" "cloudbeaver_admin" {
  metadata {
    name      = "cloudbeaver-admin"
    namespace = kubernetes_namespace_v1.cloudbeaver.metadata[0].name
  }

  data = {
    CB_ADMIN_PASSWORD = random_password.admin.result
  }
}

resource "kubernetes_secret_v1" "cloudbeaver_datasources" {
  metadata {
    name      = "cloudbeaver-datasources"
    namespace = kubernetes_namespace_v1.cloudbeaver.metadata[0].name
  }

  data = {
    "initial-data-sources.conf" = jsonencode(local.datasources)
  }
}

resource "kubernetes_deployment_v1" "cloudbeaver" {
  metadata {
    name      = local.cloudbeaver_name
    namespace = kubernetes_namespace_v1.cloudbeaver.metadata[0].name
    labels = {
      app = local.cloudbeaver_name
    }
  }

  spec {
    replicas = 1

    # The workspace is backed by a ReadWriteOnce host_path volume, so two pods
    # could not mount it simultaneously. Recreate avoids a wedged rollout where
    # the new pod is stuck Pending on the volume held by the old one.
    strategy {
      type = "Recreate"
    }

    selector {
      match_labels = {
        app = local.cloudbeaver_name
      }
    }

    template {
      metadata {
        labels = {
          app = local.cloudbeaver_name
        }
      }

      spec {
        container {
          name  = local.cloudbeaver_name
          image = "dbeaver/cloudbeaver:${var.cloudbeaver_image_version}"

          # CB_* env vars complete the initial server setup headlessly so the
          # browser-based setup wizard never appears. Anonymous access is left
          # OFF: CloudBeaver 26 hides predefined connections from anonymous users
          # (regression dbeaver/cloudbeaver#2058), so after passing oauth2-proxy
          # you sign in to CloudBeaver as this admin account, which always sees
          # the seeded global connection. Retrieve the password from the
          # admin_password output.
          env {
            name  = "CB_SERVER_NAME"
            value = "CloudBeaver"
          }

          env {
            name  = "CB_SERVER_URL"
            value = "https://${var.hostname}"
          }

          env {
            name  = "CB_ADMIN_NAME"
            value = "cbadmin"
          }

          env {
            name = "CB_ADMIN_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.cloudbeaver_admin.metadata[0].name
                key  = "CB_ADMIN_PASSWORD"
              }
            }
          }

          port {
            container_port = local.cloudbeaver_port
            name           = "http"
          }

          volume_mount {
            name       = "workspace"
            mount_path = "/opt/cloudbeaver/workspace"
          }

          # Mounted as a single file via sub_path so the rest of the image's
          # conf directory (cloudbeaver.conf etc.) is preserved.
          volume_mount {
            name       = "datasources"
            mount_path = "/opt/cloudbeaver/conf/initial-data-sources.conf"
            sub_path   = "initial-data-sources.conf"
            read_only  = true
          }

          readiness_probe {
            http_get {
              path = "/"
              port = local.cloudbeaver_port
            }
            initial_delay_seconds = 20
            period_seconds        = 10
          }

          liveness_probe {
            http_get {
              path = "/"
              port = local.cloudbeaver_port
            }
            initial_delay_seconds = 60
            period_seconds        = 30
          }
        }

        volume {
          name = "workspace"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.cloudbeaver.metadata[0].name
          }
        }

        volume {
          name = "datasources"
          secret {
            secret_name = kubernetes_secret_v1.cloudbeaver_datasources.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "cloudbeaver" {
  metadata {
    name      = local.cloudbeaver_name
    namespace = kubernetes_namespace_v1.cloudbeaver.metadata[0].name
  }

  spec {
    type = "ClusterIP"
    selector = {
      app = local.cloudbeaver_name
    }
    port {
      port        = 80
      target_port = local.cloudbeaver_port
      protocol    = "TCP"
    }
  }
}

module "cloudbeaver_oauth2_proxy" {
  source = "../setup_oauth2_proxy"

  name                       = local.cloudbeaver_name
  namespace                  = kubernetes_namespace_v1.cloudbeaver.metadata[0].name
  client_id                  = var.client_id
  client_secret              = var.client_secret
  tenant_id                  = var.tenant_id
  valid_email                = var.valid_email
  oauth2_proxy_chart_version = var.oauth2_proxy_chart_version
  oauth2_proxy_image_version = var.oauth2_proxy_image_version
  upstream_uri               = "http://${kubernetes_service_v1.cloudbeaver.metadata[0].name}.${kubernetes_namespace_v1.cloudbeaver.metadata[0].name}.svc.cluster.local:80"
  session_redis              = var.session_redis

  depends_on = [kubernetes_deployment_v1.cloudbeaver]
}

resource "kubectl_manifest" "cloudbeaver_httproute" {
  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "cloudbeaver"
      namespace = kubernetes_namespace_v1.cloudbeaver.metadata[0].name
    }
    spec = {
      parentRefs = [{
        name        = "traefik"
        namespace   = "traefik"
        sectionName = "websecure"
      }]
      hostnames = [var.hostname]
      rules = [{
        backendRefs = [{
          name = module.cloudbeaver_oauth2_proxy.service_name
          port = 80
        }]
      }]
    }
  })

  depends_on = [module.cloudbeaver_oauth2_proxy]
}
