terraform {
  required_providers {
    ansible = {
      source = "ansible/ansible"
    }

    tls = {
      source = "hashicorp/tls"
    }

    random = {
      source = "hashicorp/random"
    }

    local = {
      source = "hashicorp/local"
    }

    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}
