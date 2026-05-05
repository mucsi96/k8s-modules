terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }

    azuread = {
      source = "hashicorp/azuread"
    }

    kubernetes = {
      source = "hashicorp/kubernetes"
    }

    helm = {
      source = "hashicorp/helm"
    }

    tls = {
      source = "hashicorp/tls"
    }

    acme = {
      source = "vancluever/acme"
    }

    cloudflare = {
      source = "cloudflare/cloudflare"
    }

    random = {
      source = "hashicorp/random"
    }
  }
}
