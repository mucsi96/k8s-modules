terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = ">= 1.48.0"
    }

    ansible = {
      source = "ansible/ansible"
    }

    tls = {
      source = "hashicorp/tls"
    }

    random = {
      source = "hashicorp/random"
    }

    local = {
      source = "hashicorp/local"
    }

    azurerm = {
      source = "hashicorp/azurerm"
    }

    helm = {
      source = "hashicorp/helm"
    }
  }
}
