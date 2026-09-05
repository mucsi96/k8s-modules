locals {
  app_hostname = "expenses.${var.hostname}"
}

module "app_base" {
  source = "../setup_app_base"

  github_repository      = "expense-tracker"
  environment_name       = var.environment_name
  app_name               = "expense-tracker"
  azure_location         = var.azure_location
  tenant_id              = var.tenant_id
  azure_subscription_id  = var.azure_subscription_id
  owner                  = var.owner
  twingate_service_key   = var.twingate_service_key
  app_hostname           = local.app_hostname
  api_client_id          = module.setup_expense_tracker_api.client_id
  api_client_secret      = module.setup_expense_tracker_api.client_secret
  spa_client_id          = module.setup_expense_tracker_spa.client_id
  api_resource_object_id = module.setup_expense_tracker_api.resource_object_id
  k8s_oidc_config        = var.k8s_oidc_config
  client_log_url         = var.client_log_url
}

module "setup_expense_tracker_api" {
  source = "../register_api"
  owner  = var.owner

  display_name = "Expense Tracker API"
  roles        = ["ExpenseReader"]
  scopes       = ["readExpenses", "createExpenses", "deleteExpenses"]

  k8s_oidc_issuer_url           = var.k8s_oidc_issuer_url
  k8s_service_account_namespace = "expense-tracker"
  k8s_service_account_name      = "expense-tracker-api-workload-identity"
}

module "setup_expense_tracker_spa" {
  source = "../register_spa"
  owner  = var.owner

  display_name  = "Expense Tracker SPA"
  redirect_uris = ["https://${local.app_hostname}/", "http://localhost:4205/"]

  api_id        = module.setup_expense_tracker_api.application_id
  api_client_id = module.setup_expense_tracker_api.client_id
  api_scope_ids = [
    module.setup_expense_tracker_api.scope_ids["readExpenses"],
    module.setup_expense_tracker_api.scope_ids["createExpenses"],
    module.setup_expense_tracker_api.scope_ids["deleteExpenses"]
  ]
}

resource "kubernetes_persistent_volume_v1" "expense_tracker_app_pv" {
  metadata {
    name = "expense-tracker-app"
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
        path = "/data/expense-tracker"
      }
    }
  }
}

resource "kubernetes_persistent_volume_v1" "expense_tracker_backup_pv" {
  metadata {
    name = "expense-tracker-backup"
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
        path = "/data/expense-tracker"
      }
    }
  }
}
