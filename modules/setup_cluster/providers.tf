terraform {
  required_providers {
    ansible = {
      source = "ansible/ansible"
    }

    azurerm = {
      source = "hashicorp/azurerm"
    }

    helm = {
      source = "hashicorp/helm"
    }
  }
}
