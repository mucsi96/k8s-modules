locals {
  app_hostname      = "cooking.${var.hostname}"
  browser_client_id = nonsensitive(var.forward_auth == null) ? module.setup_cooking_spa[0].client_id : module.setup_cooking_web[0].client_id
}

module "postgres_schema" {
  source = "../setup_postgres_schema"

  database = var.database
  schema   = "cooking"
}

module "app_base" {
  source = "../setup_app_base"

  github_repository = "cooking-app"
  environment_name  = var.environment_name
  app_name          = "cooking"
  app_secrets = {
    claude-api-key = var.claude_api_key
    openai-api-key = var.openai_api_key
  }
  deployment_secrets = nonsensitive(var.forward_auth == null) ? {} : {
    forward-auth-config = jsonencode(module.forward_auth[0].deployment_config)
    client-runtime-config = jsonencode({
      clientLogUrl  = var.client_log_url
      clientAppName = "cooking-client"
    })
  }
  azure_location         = var.azure_location
  tenant_id              = var.tenant_id
  azure_subscription_id  = var.azure_subscription_id
  owner                  = var.owner
  twingate_service_key   = var.twingate_service_key
  app_hostname           = local.app_hostname
  api_client_id          = module.setup_cooking_api.client_id
  api_client_secret      = module.setup_cooking_api.client_secret
  spa_client_id          = local.browser_client_id
  api_resource_object_id = module.setup_cooking_api.resource_object_id
  k8s_oidc_config        = var.k8s_oidc_config
  client_log_url         = var.client_log_url
}

module "setup_cooking_api" {
  source = "../register_api"
  owner  = var.owner

  display_name = "Cooking API"
  roles        = ["readRecipes", "createRecipe"]

  k8s_oidc_issuer_url           = var.k8s_oidc_issuer_url
  k8s_service_account_namespace = "cooking"
  k8s_service_account_name      = "cooking-api-workload-identity"
}

module "setup_cooking_spa" {
  source = "../register_spa"
  count  = nonsensitive(var.forward_auth == null ? 1 : 0)
  owner  = var.owner

  display_name  = "Cooking SPA"
  redirect_uris = ["https://${local.app_hostname}/", "http://localhost:4260/"]

  api_id        = module.setup_cooking_api.application_id
  api_client_id = module.setup_cooking_api.client_id
  api_scope_id  = module.setup_cooking_api.scope_id
}

module "setup_cooking_web" {
  source = "../register_web"
  count  = nonsensitive(var.forward_auth == null ? 0 : 1)
  owner  = var.owner

  display_name  = "Cooking Web"
  redirect_uris = ["https://${local.app_hostname}/oauth2/callback"]
  api_access = {
    application_id = module.setup_cooking_api.application_id
    client_id      = module.setup_cooking_api.client_id
    scope_id       = module.setup_cooking_api.scope_id
  }
  allowed_user_ids = toset([for user in data.azuread_users.all.users : user.object_id])
}

module "forward_auth" {
  source = "../setup_app_forwardauth"
  count  = nonsensitive(var.forward_auth == null ? 0 : 1)

  name                = "cooking"
  namespace           = module.app_base.namespace
  hostname            = local.app_hostname
  tenant_id           = var.tenant_id
  client_id           = module.setup_cooking_web[0].client_id
  client_secret       = module.setup_cooking_web[0].client_secret
  api_client_id       = module.setup_cooking_api.client_id
  trusted_proxy_cidrs = nonsensitive(var.forward_auth.trusted_proxy_cidrs)
  session_redis       = var.forward_auth.session_redis
  gateway_parent_ref  = var.forward_auth.gateway_parent_ref
}

# Every user in the tenant gets both recipe roles — the whole household uses
# the cooking app. register_api already assigns all roles to the owner, so
# the owner is excluded here to avoid a duplicate assignment.
data "azuread_users" "all" {
  return_all = true
}

resource "azuread_app_role_assignment" "all_users" {
  for_each = {
    for pair in setproduct(
      ["readRecipes", "createRecipe"],
      [for user in data.azuread_users.all.users : user.object_id if user.object_id != var.owner]
    ) : "${pair[0]}-${pair[1]}" => pair
  }

  app_role_id         = module.setup_cooking_api.roles_ids[each.value[0]]
  principal_object_id = each.value[1]
  resource_object_id  = module.setup_cooking_api.resource_object_id
}

resource "kubernetes_persistent_volume_v1" "cooking_app_pv" {
  metadata {
    name = "cooking-app"
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
        path = "/data/cooking"
      }
    }
  }
}

resource "kubernetes_persistent_volume_v1" "cooking_backup_pv" {
  metadata {
    name = "cooking-backup"
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
        path = "/data/cooking"
      }
    }
  }
}
