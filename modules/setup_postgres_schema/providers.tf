terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 5.4.0, < 6.0.0"
    }

    kubernetes = {
      source = "hashicorp/kubernetes"
    }

    random = {
      source = "hashicorp/random"
    }
  }
}
