resource "random_password" "password" {
  length  = 32
  special = false
}

resource "kubernetes_persistent_volume_v1" "redis" {
  metadata {
    name = "redis"
  }

  spec {
    storage_class_name = ""
    access_modes       = ["ReadWriteOnce"]
    capacity = {
      storage = "1Gi"
    }
    persistent_volume_reclaim_policy = "Retain"
    persistent_volume_source {
      host_path {
        path = "/data/redis"
      }
    }
  }
}

resource "helm_release" "redis" {
  name       = var.k8s_name
  repository = "https://mucsi96.github.io/k8s-helm-charts"
  chart      = "redis"
  version    = "2.0.0"
  namespace  = var.k8s_namespace
  wait       = true
  # https://github.com/mucsi96/k8s-helm-charts/tree/main/charts/redis
  values = [yamlencode({
    password = random_password.password.result
    persistentVolumeClaim = {
      storageClassName = ""
      volumeName       = kubernetes_persistent_volume_v1.redis.metadata[0].name
      accessMode       = "ReadWriteOnce"
    }
  })]
}
