terraform {
  required_version = ">= 1.7"
  required_providers {
    kubernetes = { source = "hashicorp/kubernetes", version = ">= 2.35.0" }
    kubectl    = { source = "gavinbunney/kubectl", version = ">= 1.14.0" }
    azuread    = { source = "hashicorp/azuread", version = ">= 3.0.0" }
    helm       = { source = "hashicorp/helm", version = ">= 2.16.1" }
    random     = { source = "hashicorp/random", version = ">= 3.6.0" }
    azurerm    = { source = "hashicorp/azurerm", version = ">= 4.0.0" }
    github     = { source = "integrations/github", version = ">= 6.0.0" }
  }
}
