terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.14.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.35.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = ">=2.16.1"
    }

    tls = {
      source  = "hashicorp/tls"
      version = ">=4.0.6"
    }

    acme = {
      source  = "vancluever/acme"
      version = ">= 2.28.2"
    }

    ansible = {
      source  = "ansible/ansible"
      version = ">= 1.3.0"
    }

    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "5.19.1"
    }

    twingate = {
      source  = "Twingate/twingate"
      version = "4.1.1"
    }

    github = {
      source  = "integrations/github"
      version = ">= 6.0.0"
    }

    docker = {
      source  = "docker/docker"
      version = ">= 0.2.0"
    }

    hcloud = {
      source  = "hetznercloud/hcloud"
      version = ">= 1.48.0"
    }

    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14.0"
    }
  }

  required_version = ">= 1.2"
}

provider "random" {}

provider "azurerm" {
  features {}
  subscription_id = var.azure_subscription_id
}

provider "azuread" {}

provider "ansible" {}



provider "kubernetes" {
  host                   = module.setup_cluster.k8s_host
  client_certificate     = module.setup_cluster.k8s_client_certificate
  client_key             = module.setup_cluster.k8s_client_key
  cluster_ca_certificate = module.setup_cluster.k8s_cluster_ca_certificate
}

provider "helm" {
  kubernetes = {
    host                   = module.setup_cluster.k8s_host
    client_certificate     = module.setup_cluster.k8s_client_certificate
    client_key             = module.setup_cluster.k8s_client_key
    cluster_ca_certificate = module.setup_cluster.k8s_cluster_ca_certificate
  }
}

# Used in place of hashicorp/kubernetes's kubernetes_manifest for CRDs (Traefik
# IngressRoute / Middleware). kubernetes_manifest opens a REST client at plan
# time and breaks the from-scratch apply because the cluster does not exist
# yet; kubectl_manifest defers the connection to apply time.
provider "kubectl" {
  host                   = module.setup_cluster.k8s_host
  client_certificate     = module.setup_cluster.k8s_client_certificate
  client_key             = module.setup_cluster.k8s_client_key
  cluster_ca_certificate = module.setup_cluster.k8s_cluster_ca_certificate
  load_config_file       = false
}

provider "acme" {
  # server_url = "https://acme-staging-v02.api.letsencrypt.org/directory" # Staging server
  server_url = "https://acme-v02.api.letsencrypt.org/directory" # Production server
}

provider "cloudflare" {
  api_token = data.azurerm_key_vault_secret.cloudflare_api_token.value
}

provider "twingate" {
  api_token = data.azurerm_key_vault_secret.twingate_api_token.value
  network   = data.azurerm_key_vault_secret.twingate_network.value
}

provider "github" {
  owner = "mucsi96"
  token = data.azurerm_key_vault_secret.github_token.value
}

provider "docker" {}

provider "hcloud" {
  token = data.azurerm_key_vault_secret.hcloud_token.value
}

data "azurerm_key_vault" "kv" {
  resource_group_name = var.environment_name
  name                = var.environment_name
}

data "azurerm_key_vault_secret" "hcloud_token" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "hcloud-token"
}

module "provision_hetzner_server" {
  source      = "./modules/provision_hetzner_server"
  server_name = var.environment_name
  server_type = var.hcloud_server_type
  location    = var.hcloud_location
  image       = var.hcloud_image
  username    = var.hcloud_username
  labels = {
    environment = var.environment_name
  }
}

module "setup_cluster" {
  source                        = "./modules/setup_cluster"
  host                          = module.provision_hetzner_server.ipv4_address
  ssh_port                      = module.provision_hetzner_server.ssh_port
  username                      = module.provision_hetzner_server.username
  azure_key_vault_name          = data.azurerm_key_vault.kv.name
  environment_name              = var.environment_name
  azure_subscription_id         = var.azure_subscription_id
  storage_account_name          = var.storage_account_name
  azure_tenant_id               = data.azurerm_client_config.current.tenant_id
  owner                         = local.owner
  cluster_monitor_redirect_uris = ["https://${local.k8s_dashboard_hostname}/oauth2/callback"]
  local_python_interpreter      = var.local_python_interpreter
  wait_for                      = module.provision_hetzner_server.ssh_ready
}

locals {
  k8s_dashboard_hostname = "k8s.${data.azurerm_key_vault_secret.dns_zone.value}"
  grafana_hostname       = "grafana.${data.azurerm_key_vault_secret.dns_zone.value}"
  prometheus_hostname    = "prometheus.${data.azurerm_key_vault_secret.dns_zone.value}"
  pgweb_hostname         = "db.${data.azurerm_key_vault_secret.dns_zone.value}"
  faro_hostname          = "faro.${data.azurerm_key_vault_secret.dns_zone.value}"
  # /collect is the path the Faro Web SDK POSTs telemetry to. Stored verbatim
  # in each app's Key Vault so the SPA can use it without further URL juggling.
  client_log_url = "https://${local.faro_hostname}/collect"
}

module "register_grafana_dashboard" {
  source = "./modules/register_webapp"

  display_name  = "Grafana - ${var.environment_name}"
  owner         = local.owner
  redirect_uris = ["https://${local.grafana_hostname}/oauth2/callback"]
}

module "register_prometheus_dashboard" {
  source = "./modules/register_webapp"

  display_name  = "Prometheus - ${var.environment_name}"
  owner         = local.owner
  redirect_uris = ["https://${local.prometheus_hostname}/oauth2/callback"]
}

module "register_pgweb_dashboard" {
  source = "./modules/register_webapp"

  display_name  = "pgweb - ${var.environment_name}"
  owner         = local.owner
  redirect_uris = ["https://${local.pgweb_hostname}/oauth2/callback"]
}

data "azurerm_key_vault_secret" "dns_zone" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "dns-zone"
}

data "azurerm_key_vault_secret" "cloudflare_zone_id" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "cloudflare-zone-id"
}

data "azurerm_key_vault_secret" "cloudflare_account_id" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "cloudflare-account-id"
}

data "azurerm_key_vault_secret" "cloudflare_api_token" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "cloudflare-api-token"
}

data "azurerm_key_vault_secret" "authorized_as" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "authorized-as"
}

data "azurerm_key_vault_secret" "twingate_api_token" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "twingate-api-token"
}

data "azurerm_key_vault_secret" "twingate_network" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "twingate-network"
}

data "azurerm_key_vault_secret" "github_token" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "github-token"
}

data "azurerm_key_vault_secret" "letsencrypt_email" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "letsencrypt-email"
}

module "create_redis_namespace" {
  source           = "./modules/create_app_namespace"
  environment_name = var.environment_name
  k8s_namespace    = "redis"

  k8s_host                   = module.setup_cluster.k8s_host
  k8s_cluster_ca_certificate = module.setup_cluster.k8s_cluster_ca_certificate
}

module "create_redis" {
  source        = "./modules/setup_redis"
  k8s_name      = "redis"
  k8s_namespace = module.create_redis_namespace.k8s_namespace
}

module "setup_ingress_controller" {
  source                     = "./modules/setup_ingress_controller"
  environment_name           = var.environment_name
  subscription_id            = var.azure_subscription_id
  dns_zone                   = data.azurerm_key_vault_secret.dns_zone.value
  traefik_chart_version      = "39.0.8"  #https://github.com/traefik/traefik-helm-chart/releases
  traefik_version            = "v3.6.14" #https://github.com/traefik/traefik/releases
  cloudflare_api_token       = data.azurerm_key_vault_secret.cloudflare_api_token.value
  cloudflare_account_id      = data.azurerm_key_vault_secret.cloudflare_account_id.value
  cloudflare_zone_id         = data.azurerm_key_vault_secret.cloudflare_zone_id.value
  authorized_as              = data.azurerm_key_vault_secret.authorized_as.value
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  owner                      = local.owner
  oauth2_proxy_chart_version = "7.12.6"  #https://github.com/oauth2-proxy/manifests/releases
  oauth2_proxy_image_version = "v7.12.0" #https://github.com/oauth2-proxy/oauth2-proxy/releases
  valid_email                = data.azurerm_key_vault_secret.letsencrypt_email.value
  session_redis = {
    connection_url = module.create_redis.connection_url
    password       = module.create_redis.password
  }
  depends_on = [module.setup_cluster]
}

module "setup_twingate" {
  source             = "./modules/setup_twingate"
  environment_name   = var.environment_name
  twingate_network   = data.azurerm_key_vault_secret.twingate_network.value
  twingate_api_token = data.azurerm_key_vault_secret.twingate_api_token.value
  k8s_host           = module.provision_hetzner_server.ipv4_address
  depends_on         = [module.setup_cluster]
}

module "create_database_namespace" {
  source           = "./modules/create_app_namespace"
  environment_name = var.environment_name
  k8s_namespace    = "db"

  k8s_host                   = module.setup_cluster.k8s_host
  k8s_cluster_ca_certificate = module.setup_cluster.k8s_cluster_ca_certificate
  wait_for                   = module.setup_ingress_controller.traefik_ready
}

module "create_database" {
  source        = "./modules/create_postgres_database"
  k8s_name      = "postgres1"
  k8s_namespace = module.create_database_namespace.k8s_namespace
  db_name       = "postgres1"
}

data "azurerm_client_config" "current" {}

locals {
  owner = data.azurerm_client_config.current.object_id
  db = {
    host     = module.create_database.host
    port     = module.create_database.port
    database = module.create_database.name
    username = module.create_database.username
    password = module.create_database.password
  }
}

module "setup_backup_app" {
  source                     = "./modules/setup_backup_app"
  environment_name           = var.environment_name
  azure_location             = var.azure_location
  owner                      = local.owner
  k8s_host                   = module.setup_cluster.k8s_host
  k8s_cluster_ca_certificate = module.setup_cluster.k8s_cluster_ca_certificate
  k8s_oidc_issuer_url        = module.setup_cluster.oidc_issuer_url
  hostname                   = data.azurerm_key_vault_secret.dns_zone.value
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  azure_subscription_id      = var.azure_subscription_id
  k8s_oidc_config            = module.setup_cluster.k8s_oidc_config
  client_log_url             = local.client_log_url
  twingate_service_key       = module.setup_twingate.service_key
  wait_for                   = module.setup_ingress_controller.traefik_ready

  azure_storage_account_resource_group_name = "ibari"
  azure_storage_account_name                = "ibari"

  dbs_config = [
    merge(local.db, {
      name            = "Learn language"
      schema          = "learn_language"
      createPlainDump = true
      folderBackups = [
        {
          path = "/app/storage/learn-language"
        }
      ]
      excludeTables = [
        "study_sessions",
        "study_session_cards",
        "model_usage_logs",
        "unhealthy_cards",
        "api_tokens"
      ]
    }),
    merge(local.db, {
      name            = "Training log"
      schema          = "training_log"
      createPlainDump = true
      folderBackups = [
        {
          path = "/app/storage/training-log"
        }
      ]
      excludeTables = [
        "oauth2_authorized_client"
      ]
    }),
    merge(local.db, {
      name            = "Grafana"
      schema          = "grafana"
      createPlainDump = true
    })
  ]
}

module "setup_learn_language_app" {
  source                     = "./modules/setup_learn_language_app"
  environment_name           = var.environment_name
  azure_location             = var.azure_location
  owner                      = local.owner
  k8s_host                   = module.setup_cluster.k8s_host
  k8s_cluster_ca_certificate = module.setup_cluster.k8s_cluster_ca_certificate
  k8s_oidc_issuer_url        = module.setup_cluster.oidc_issuer_url
  hostname                   = data.azurerm_key_vault_secret.dns_zone.value
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  azure_subscription_id      = var.azure_subscription_id
  k8s_oidc_config            = module.setup_cluster.k8s_oidc_config
  client_log_url             = local.client_log_url
  db_jdbc_url                = module.create_database.jdbc_url
  db_username                = module.create_database.username
  db_password                = module.create_database.password
  twingate_service_key       = module.setup_twingate.service_key
  wait_for                   = module.setup_ingress_controller.traefik_ready
}

module "setup_hello_app" {
  source                     = "./modules/setup_hello_app"
  environment_name           = var.environment_name
  azure_location             = var.azure_location
  owner                      = local.owner
  k8s_host                   = module.setup_cluster.k8s_host
  k8s_cluster_ca_certificate = module.setup_cluster.k8s_cluster_ca_certificate
  k8s_oidc_issuer_url        = module.setup_cluster.oidc_issuer_url
  hostname                   = data.azurerm_key_vault_secret.dns_zone.value
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  azure_subscription_id      = var.azure_subscription_id
  k8s_oidc_config            = module.setup_cluster.k8s_oidc_config
  client_log_url             = local.client_log_url
  db_jdbc_url                = module.create_database.jdbc_url
  db_username                = module.create_database.username
  db_password                = module.create_database.password
  twingate_service_key       = module.setup_twingate.service_key
  wait_for                   = module.setup_ingress_controller.traefik_ready
}

module "setup_metrics_server" {
  source                       = "./modules/setup_metrics_server"
  metrics_server_chart_version = "3.12.2" #https://github.com/kubernetes-sigs/metrics-server/releases
  metrics_server_image_version = "v0.7.2" #https://github.com/kubernetes-sigs/metrics-server/releases
  wait_for                     = module.setup_ingress_controller.traefik_ready
}

module "setup_k8s_dashboard" {
  source                     = "./modules/setup_k8s_dashboard"
  hostname                   = local.k8s_dashboard_hostname
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  client_id                  = module.setup_cluster.cluster_monitor_client_id
  client_secret              = module.setup_cluster.cluster_monitor_client_secret
  valid_email                = data.azurerm_key_vault_secret.letsencrypt_email.value
  headlamp_chart_version     = "0.41.0"  #https://github.com/headlamp-k8s/headlamp/releases
  headlamp_image_version     = "v0.41.0" #https://github.com/headlamp-k8s/headlamp/releases
  oauth2_proxy_chart_version = "7.12.6"  #https://github.com/oauth2-proxy/manifests/releases
  oauth2_proxy_image_version = "v7.12.0" #https://github.com/oauth2-proxy/oauth2-proxy/releases
  session_redis = {
    connection_url = module.create_redis.connection_url
    password       = module.create_redis.password
  }
  wait_for = module.setup_metrics_server.metrics_server_ready
}

module "setup_prometheus_operator" {
  source                              = "./modules/setup_prometheus_operator"
  grafana_hostname                    = local.grafana_hostname
  prometheus_hostname                 = local.prometheus_hostname
  tenant_id                           = data.azurerm_client_config.current.tenant_id
  grafana_client_id                   = module.register_grafana_dashboard.client_id
  grafana_client_secret               = module.register_grafana_dashboard.client_secret
  prometheus_client_id                = module.register_prometheus_dashboard.client_id
  prometheus_client_secret            = module.register_prometheus_dashboard.client_secret
  valid_email                         = data.azurerm_key_vault_secret.letsencrypt_email.value
  kube_prometheus_stack_chart_version = "84.5.0"  #https://github.com/prometheus-community/helm-charts/releases?q=kube-prometheus-stack
  oauth2_proxy_chart_version          = "7.12.6"  #https://github.com/oauth2-proxy/manifests/releases
  oauth2_proxy_image_version          = "v7.12.0" #https://github.com/oauth2-proxy/oauth2-proxy/releases
  session_redis = {
    connection_url = module.create_redis.connection_url
    password       = module.create_redis.password
  }
  database = {
    host           = module.create_database.host
    port           = module.create_database.port
    name           = module.create_database.name
    admin_username = module.create_database.username
    admin_password = module.create_database.password
  }
  wait_for = module.setup_ingress_controller.traefik_ready
}

module "setup_loki" {
  source              = "./modules/setup_loki"
  loki_chart_version  = "7.0.0" #https://github.com/grafana/loki/blob/main/production/helm/loki/Chart.yaml
  alloy_chart_version = "1.8.1" #https://github.com/grafana/helm-charts/releases?q=alloy
  grafana_namespace   = module.setup_prometheus_operator.namespace
  faro_hostname       = local.faro_hostname
  # Production hostnames of the 4 apps only. Local dev origins are
  # intentionally excluded — Faro is a production-only signal.
  faro_cors_allowed_origins = [
    "https://hello.${data.azurerm_key_vault_secret.dns_zone.value}",
    "https://language.${data.azurerm_key_vault_secret.dns_zone.value}",
    "https://training.${data.azurerm_key_vault_secret.dns_zone.value}",
    "https://backup.${data.azurerm_key_vault_secret.dns_zone.value}",
  ]
  wait_for = module.setup_prometheus_operator.kube_prometheus_stack_ready
}

module "setup_pgweb" {
  source                     = "./modules/setup_pgweb"
  hostname                   = local.pgweb_hostname
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  client_id                  = module.register_pgweb_dashboard.client_id
  client_secret              = module.register_pgweb_dashboard.client_secret
  valid_email                = data.azurerm_key_vault_secret.letsencrypt_email.value
  pgweb_image_version        = "0.16.2"  #https://github.com/sosedoff/pgweb/releases
  oauth2_proxy_chart_version = "7.12.6"  #https://github.com/oauth2-proxy/manifests/releases
  oauth2_proxy_image_version = "v7.12.0" #https://github.com/oauth2-proxy/oauth2-proxy/releases
  session_redis = {
    connection_url = module.create_redis.connection_url
    password       = module.create_redis.password
  }
  database = {
    name     = module.create_database.name
    host     = module.create_database.host
    port     = module.create_database.port
    username = module.create_database.username
    password = module.create_database.password
  }
  wait_for = module.setup_ingress_controller.traefik_ready
}

module "setup_training_log_app" {
  source                     = "./modules/setup_training_log_app"
  environment_name           = var.environment_name
  azure_location             = var.azure_location
  owner                      = local.owner
  k8s_host                   = module.setup_cluster.k8s_host
  k8s_cluster_ca_certificate = module.setup_cluster.k8s_cluster_ca_certificate
  k8s_oidc_issuer_url        = module.setup_cluster.oidc_issuer_url
  hostname                   = data.azurerm_key_vault_secret.dns_zone.value
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  azure_subscription_id      = var.azure_subscription_id
  k8s_oidc_config            = module.setup_cluster.k8s_oidc_config
  client_log_url             = local.client_log_url
  db_jdbc_url                = module.create_database.jdbc_url
  db_username                = module.create_database.username
  db_password                = module.create_database.password
  twingate_service_key       = module.setup_twingate.service_key
  wait_for                   = module.setup_ingress_controller.traefik_ready
}
