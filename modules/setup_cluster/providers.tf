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

    random = {
      source = "hashicorp/random"
    }
  }
}
