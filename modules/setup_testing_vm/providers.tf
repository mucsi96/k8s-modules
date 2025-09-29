terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }

    random = {
      source  = "hashicorp/random"
      version = ">=3.6.3"
    }
  }
}
