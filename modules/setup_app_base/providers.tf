terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }

    azuread = {
      source = "hashicorp/azuread"
    }

    github = {
      source = "integrations/github"
    }

    docker = {
      source = "docker/docker"
    }

    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}
