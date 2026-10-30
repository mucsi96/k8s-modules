terraform {
  required_providers {
    helm = {
      source = "hashicorp/helm"
    }
    random = {
      source = "hashicorp/random"
    }

    azurerm = {
      source = "hashicorp/azurerm"
    }

    azuread = {
      source = "hashicorp/azuread"
    }

    kubernetes = {
      source = "hashicorp/kubernetes"
    }

    github = {
      source = "integrations/github"
    }
  }
}
