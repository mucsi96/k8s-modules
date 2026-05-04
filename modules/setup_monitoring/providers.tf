terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }

    helm = {
      source = "hashicorp/helm"
    }

    cloudflare = {
      source = "cloudflare/cloudflare"
    }

    random = {
      source = "hashicorp/random"
    }
  }
}
