terraform {
  required_providers {
    ansible = {
      source  = "ansible/ansible"
      version = ">=1.3.0"
    }

    tls = {
      source  = "hashicorp/tls"
      version = ">=4.0.5"
    }

    random = {
      source  = "hashicorp/random"
      version = ">=3.6.3"
    }
  }
}
