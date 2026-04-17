terraform {
  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
    }

    tls = {
      source = "hashicorp/tls"
    }

    random = {
      source = "hashicorp/random"
    }
  }
}
