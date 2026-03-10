module "create_film_namespace" {
  source                     = "../create_app_namespace"
  environment_name           = var.environment_name
  k8s_namespace              = "film"
  k8s_host                   = var.k8s_host
  k8s_cluster_ca_certificate = var.k8s_cluster_ca_certificate
}

module "setup_film_api" {
  source = "../register_api"
  owner  = var.owner

  display_name = "Film API"
  roles        = ["FilmReader", "FilmCreator"]
  scopes       = ["readFilms", "createFilm"]

  k8s_oidc_issuer_url           = var.k8s_oidc_issuer_url
  k8s_service_account_namespace = "film"
  k8s_service_account_name      = "film-api-workload-identity"
}

module "setup_film_spa" {
  source = "../register_spa"
  owner  = var.owner

  display_name  = "Film SPA"
  redirect_uris = ["https://film.${var.hostname}/", "http://localhost:4200/"]

  api_id        = module.setup_film_api.application_id
  api_client_id = module.setup_film_api.client_id
  api_scope_ids = [
    module.setup_film_api.scope_ids["readFilms"],
    module.setup_film_api.scope_ids["createFilm"]
  ]
}

resource "kubernetes_persistent_volume_v1" "film_app_pv" {
  metadata {
    name = "film-app"
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
        path = "/data/film"
      }
    }
  }
}

resource "kubernetes_persistent_volume_v1" "film_backup_pv" {
  metadata {
    name = "film-backup"
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
        path = "/data/film"
      }
    }
  }
}
