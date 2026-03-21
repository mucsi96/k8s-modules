resource "twingate_remote_network" "home_cluster" {
  name     = "${var.environment_name} cluster"
  location = "ON_PREMISE"
}

resource "twingate_connector" "home_cluster" {
  remote_network_id      = twingate_remote_network.home_cluster.id
  name                   = "${var.environment_name}-connector"
  status_updates_enabled = true
}

resource "twingate_connector_tokens" "home_cluster" {
  connector_id = twingate_connector.home_cluster.id
}

resource "kubernetes_namespace_v1" "twingate" {
  metadata {
    name = "twingate"
  }
}

resource "kubernetes_secret_v1" "twingate_connector" {
  metadata {
    name      = "twingate-connector"
    namespace = kubernetes_namespace_v1.twingate.metadata[0].name
  }

  data = {
    TWINGATE_ACCESS_TOKEN  = twingate_connector_tokens.home_cluster.access_token
    TWINGATE_REFRESH_TOKEN = twingate_connector_tokens.home_cluster.refresh_token
  }
}

resource "helm_release" "twingate_connector" {
  name       = "twingate-connector"
  repository = "https://twingate.github.io/helm-charts"
  chart      = "connector"
  namespace  = kubernetes_namespace_v1.twingate.metadata[0].name

  values = [yamlencode({
    connector = {
      network        = var.twingate_network
      existingSecret = kubernetes_secret_v1.twingate_connector.metadata[0].name
    }
  })]
}

resource "twingate_resource" "k8s_api" {
  name              = "${var.environment_name} Kubernetes API"
  remote_network_id = twingate_remote_network.home_cluster.id
  address           = var.k8s_host

  protocols = {
    allow_icmp = false
    tcp = {
      policy = "RESTRICTED"
      ports  = ["16443"]
    }
    udp = {
      policy = "DENY_ALL"
    }
  }
}

resource "twingate_service_account" "github_actions" {
  name = "${var.environment_name}-github-actions"
}

resource "twingate_service_account_key" "github_actions" {
  service_account_id = twingate_service_account.github_actions.id
  name               = "${var.environment_name}-github-actions-key"
}

resource "twingate_resource_access" "github_actions_k8s" {
  resource_id        = twingate_resource.k8s_api.id
  service_account_id = twingate_service_account.github_actions.id
}
