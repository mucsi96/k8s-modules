terraform {
  required_providers {
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
