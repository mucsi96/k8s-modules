module "create_reading_tracker_namespace" {
  source                     = "../create_app_namespace"
  environment_name           = var.environment_name
  k8s_namespace              = "reading-tracker"
  k8s_host                   = var.k8s_host
  k8s_cluster_ca_certificate = var.k8s_cluster_ca_certificate
}

module "setup_reading_tracker_api" {
  source = "../register_api"
  owner  = var.owner

  display_name = "Reading Tracker API"
  roles        = ["BookReader", "BookCreator"]
  scopes       = ["readBooks", "createBook"]

  k8s_oidc_issuer_url           = var.k8s_oidc_issuer_url
  k8s_service_account_namespace = "reading-tracker"
  k8s_service_account_name      = "reading-tracker-api-workload-identity"
}

module "setup_reading_tracker_spa" {
  source = "../register_spa"
  owner  = var.owner

  display_name  = "Reading Tracker SPA"
  redirect_uris = ["https://reading.${var.hostname}/", "http://localhost:4200/"]

  api_id        = module.setup_reading_tracker_api.application_id
  api_client_id = module.setup_reading_tracker_api.client_id
  api_scope_ids = [
    module.setup_reading_tracker_api.scope_ids["readBooks"],
    module.setup_reading_tracker_api.scope_ids["createBook"]
  ]
}

resource "kubernetes_persistent_volume_v1" "reading_tracker_app_pv" {
  metadata {
    name = "reading-tracker-app"
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
        path = "/data/reading-tracker"
      }
    }
  }
}

resource "kubernetes_persistent_volume_v1" "reading_tracker_backup_pv" {
  metadata {
    name = "reading-tracker-backup"
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
        path = "/data/reading-tracker"
      }
    }
  }
}
