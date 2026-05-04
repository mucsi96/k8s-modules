terraform {
  required_providers {
    random = {
      source = "hashicorp/random"
    }

    kubernetes = {
      source = "hashicorp/kubernetes"
    }

    helm = {
      source = "hashicorp/helm"
    }
  }
}
