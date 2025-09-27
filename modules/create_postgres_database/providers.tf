terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = ">=3.6.3"
    }

    helm = {
      source  = "hashicorp/helm"
      version = ">=2.16.1"
    }
  }
}
