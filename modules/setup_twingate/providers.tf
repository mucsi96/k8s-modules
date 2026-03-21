terraform {
  required_providers {
    twingate = {
      source = "Twingate/twingate"
    }

    kubernetes = {
      source = "hashicorp/kubernetes"
    }

    helm = {
      source = "hashicorp/helm"
    }
  }
}
