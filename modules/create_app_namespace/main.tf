terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=4.14.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">=2.35.0"
    }
  }
}

data "azurerm_kubernetes_cluster" "kubernetes_cluster" {
  name                = var.azure_resource_group_name
  resource_group_name = var.azure_resource_group_name
}

resource "kubernetes_namespace" "namespace" {
  metadata {
    name = var.k8s_namespace
  }
}

resource "kubernetes_service_account" "service_account" {
  metadata {
    name      = "${var.k8s_namespace}-namespace-admin"
    namespace = var.k8s_namespace
  }
  automount_service_account_token = false
}

resource "kubernetes_cluster_role" "cluster_role" {
  metadata {
    name = var.k8s_namespace
  }

  rule {
    api_groups = [
      "",
    ]
    resources = [
      "namespaces"
    ]
    verbs = [
      "list",
    ]
  }

  rule {
    api_groups = [
      "apiextensions.k8s.io",
    ]
    resources = [
      "customresourcedefinitions"
    ]
    verbs = [
      "list",
    ]
  }
}

resource "kubernetes_role" "role" {
  metadata {
    name      = var.k8s_namespace
    namespace = var.k8s_namespace
  }

  rule {
    api_groups = [
      "", "batch", "extensions", "apps", "networking.k8s.io", "traefik.io", "monitoring.coreos.com"
    ]
    resources = [
      "*",
    ]
    verbs = [
      "*",
    ]
  }
}

resource "kubernetes_secret" "service_account_token_secret" {
  metadata {
    name      = "service-account-token"
    namespace = var.k8s_namespace
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account.service_account.metadata.0.name
    }
  }

  type                           = "kubernetes.io/service-account-token"
  wait_for_service_account_token = true
}

resource "kubernetes_role_binding" "role_binding" {
  metadata {
    name      = var.k8s_namespace
    namespace = var.k8s_namespace
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.service_account.metadata.0.name
    namespace = var.k8s_namespace

  }

  role_ref {
    kind      = "Role"
    name      = kubernetes_role.role.metadata.0.name
    api_group = "rbac.authorization.k8s.io"
  }
}

resource "kubernetes_cluster_role_binding" "cluster_role_binding" {
  metadata {
    name = var.k8s_namespace
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.service_account.metadata.0.name
    namespace = var.k8s_namespace

  }

  role_ref {
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.cluster_role.metadata.0.name
    api_group = "rbac.authorization.k8s.io"
  }
}
