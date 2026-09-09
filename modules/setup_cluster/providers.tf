terraform {
  required_providers {
    ansible = {
      source = "ansible/ansible"
    }

    azurerm = {
      source = "hashicorp/azurerm"
    }

    azuread = {
      source = "hashicorp/azuread"
    }

    helm = {
      source = "hashicorp/helm"
    }

    kubernetes = {
      source = "hashicorp/kubernetes"
    }

    github = {
      source = "integrations/github"
    }

    random = {
      source = "hashicorp/random"
    }
  }
}
