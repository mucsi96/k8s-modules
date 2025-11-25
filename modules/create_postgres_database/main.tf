resource "random_string" "db_username" {
  length  = 12
  upper   = false
  numeric = false
  special = false
}

resource "random_password" "db_password" {
  length           = 20
  special          = true
  override_special = "-_=+:[]{}" // verified: []
}

resource "random_string" "exporter_username" {
  length  = 12
  upper   = false
  numeric = false
  special = false
}

resource "random_password" "exporter_password" {
  length           = 20
  special          = true
  override_special = "-_=+:[]{}" // verified: []
}

resource "kubernetes_persistent_volume" "database_pv" {
  metadata {
    name = "database"
  }

  spec {
    storage_class_name = ""
    access_modes       = ["ReadWriteOnce"]
    capacity = {
      storage = "5Gi"
    }
    persistent_volume_reclaim_policy = "Retain"
    persistent_volume_source {
      host_path {
        path = "/data/database"
      }
    }
  }
}

resource "helm_release" "database" {
  name       = var.k8s_name
  repository = "https://mucsi96.github.io/k8s-helm-charts"
  chart      = "postgres-db"
  version    = "11.0.0"
  namespace  = var.k8s_namespace
  wait       = true
  # https://github.com/mucsi96/k8s-helm-charts/tree/main/charts/postgres_db
  values = [yamlencode({
    name = var.db_name
    persistentVolumeClaim = {
      storageClassName = ""
      volumeName       = kubernetes_persistent_volume.database_pv.metadata[0].name
      accessMode       = "ReadWriteOnce"
    }
    username         = random_string.db_username.result
    password         = random_password.db_password.result
    exporterUsername = random_string.exporter_username.result
    exporterPassword = random_password.exporter_password.result
  })]
}
