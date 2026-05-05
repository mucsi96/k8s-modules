terraform {
  required_providers {
    azuread = {
      source = "hashicorp/azuread"
    }

    kubernetes = {
      source = "hashicorp/kubernetes"
    }

    helm = {
      source = "hashicorp/helm"
    }

    random = {
      source = "hashicorp/random"
    }
  }
}
