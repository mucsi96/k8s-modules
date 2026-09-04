terraform {
  required_providers {
    external = {
      source = "hashicorp/external"
    }

    http = {
      source  = "hashicorp/http"
      version = ">= 3.6.0"
    }

    tls = {
      source = "hashicorp/tls"
    }

    random = {
      source = "hashicorp/random"
    }
  }
}
