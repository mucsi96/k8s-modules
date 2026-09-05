terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }

    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}


resource "kubernetes_namespace_v1" "namespace" {
  metadata {
    name = var.k8s_namespace
  }
}

resource "kubernetes_role_v1" "role" {
  metadata {
    name      = var.k8s_namespace
    namespace = kubernetes_namespace_v1.namespace.metadata[0].name
  }

  rule {
    api_groups = [
      "", "batch", "extensions", "apps", "networking.k8s.io", "gateway.networking.k8s.io", "monitoring.coreos.com"
    ]
    resources = [
      "*",
    ]
    verbs = [
      "*",
    ]
  }
}
