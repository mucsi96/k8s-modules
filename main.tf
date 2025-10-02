terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=4.14.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">=2.35.0"
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
      version = ">=2.28.2"
    }

    ansible = {
      source  = "ansible/ansible"
      version = ">=1.3.0"
    }

    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }

    null = {
      source  = "hashicorp/null"
      version = ">=3.2.1"
    }
  }
}

provider "random" {}

provider "null" {}

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

provider "acme" {
  # server_url = "https://acme-staging-v02.api.letsencrypt.org/directory" # Staging server
  server_url = "https://acme-v02.api.letsencrypt.org/directory" # Production server
}

variable "resource_group_name" {
  description = "Name of the Azure Resource Group to deploy resources into."
  type        = string
  default     = "p06"

}

variable "azure_location" {
  description = "Azure location used for test infrastructure resources."
  type        = string
  default     = "centralindia"
}

data "azurerm_key_vault" "kv" {
  resource_group_name = var.resource_group_name
  name                = var.resource_group_name
}

data "azurerm_key_vault_secret" "hetzner_api_token" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "hetzner-api-token"
}

provider "hcloud" {
  token = data.azurerm_key_vault_secret.hetzner_api_token.value
}

module "test_virtual_machine" {
  source   = "./modules/setup_testing_vm"
  name     = "test-vm"
  ssh_user = "ubuntu"
}

module "setup_cluster" {
  source           = "./modules/setup_cluster"
  host             = module.test_virtual_machine.public_ip_address
  initial_port     = module.test_virtual_machine.ssh_port
  username         = module.test_virtual_machine.admin_username
  initial_password = module.test_virtual_machine.admin_password
}

data "azurerm_key_vault_secret" "dns_zone" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "dns-zone"
}

# data "azurerm_key_vault_secret" "ip_range" {
#   key_vault_id = data.azurerm_key_vault.kv.id
#   name         = "ip-range"
# }

data "azurerm_key_vault_secret" "letsencrypt_email" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "letsencrypt-email"
}

module "setup_ingress_controller" {
  source                = "./modules/setup_ingress_controller"
  resource_group_name   = var.resource_group_name
  subscription_id       = var.azure_subscription_id
  dns_zone              = data.azurerm_key_vault_secret.dns_zone.value
  traefik_chart_version = "37.1.1" #https://github.com/traefik/traefik-helm-chart/releases
  letsencrypt_email     = data.azurerm_key_vault_secret.letsencrypt_email.value

  depends_on = [module.setup_cluster]
}

# module "create_database_namespace" {
#   source                    = "./modules/create_app_namespace"
#   azure_resource_group_name = module.setup_cluster.resource_group_name
#   k8s_namespace             = "db"

#   depends_on = [module.setup_ingress_controller]
# }

# module "create_database" {
#   source        = "./modules/create_postgres_database"
#   k8s_name      = "postgres1"
#   k8s_namespace = module.create_database_namespace.k8s_namespace
#   db_name       = "postgres1"
# }

# module "setup_backup_app" {
#   source                    = "./modules/setup_backup_app"
#   azure_resource_group_name = module.setup_cluster.resource_group_name
#   azure_location            = module.setup_cluster.location
#   owner                     = module.setup_cluster.owner
#   k8s_oidc_issuer_url       = module.setup_cluster.oidc_issuer_url
#   hostname                  = module.setup_ingress_controller.hostname

#   azure_storage_account_resource_group_name = "ibari"
#   azure_storage_account_name                = "ibari"

#   depends_on = [module.setup_ingress_controller]
# }

# module "create_learn_language_namespace" {
#   source                    = "./modules/create_app_namespace"
#   azure_resource_group_name = module.setup_cluster.resource_group_name
#   k8s_namespace             = "learn-language"

#   depends_on = [module.setup_ingress_controller]
# }

# module "setup_learn_language_api" {
#   source = "./modules/register_api"
#   owner  = module.setup_cluster.owner

#   display_name = "Learn Language API"
#   roles        = ["DeckReader", "DeckCreator"]
#   scopes       = ["readDecks", "createDeck"]

#   k8s_oidc_issuer_url           = module.setup_cluster.oidc_issuer_url
#   k8s_service_account_namespace = "learn-language"
#   k8s_service_account_name      = "learn-language-api-workload-identity"
# }

# module "setup_learn_language_spa" {
#   source = "./modules/register_spa"
#   owner  = module.setup_cluster.owner

#   display_name  = "Learn Language SPA"
#   redirect_uris = ["https://language.${module.setup_ingress_controller.hostname}/auth", "http://localhost:4200/auth"]

#   api_id        = module.setup_learn_language_api.application_id
#   api_client_id = module.setup_learn_language_api.client_id
#   api_scope_ids = [
#     module.setup_learn_language_api.scope_ids["readDecks"],
#     module.setup_learn_language_api.scope_ids["createDeck"]
#   ]
# }
