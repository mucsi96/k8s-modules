terraform {
  required_providers {
    random = {
      source = "hashicorp/random"
    }

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
  }
}
