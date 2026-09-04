terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }

    kubectl = {
      source = "gavinbunney/kubectl"
    }

    helm = {
      source = "hashicorp/helm"
    }

    tls = {
      source = "hashicorp/tls"
    }

    cloudflare = {
      source = "cloudflare/cloudflare"
    }
  }
}
