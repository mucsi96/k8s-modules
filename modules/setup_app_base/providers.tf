terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }

    github = {
      source = "integrations/github"
    }

    docker = {
      source = "docker/docker"
    }
  }
}
