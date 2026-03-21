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

resource "twingate_service_account" "app" {
  for_each = toset(var.app_names)
  name     = "${var.environment_name}-${each.key}"
}

resource "twingate_service_account_key" "app" {
  for_each           = toset(var.app_names)
  service_account_id = twingate_service_account.app[each.key].id
  name               = "${var.environment_name}-${each.key}-key"
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

  dynamic "access_service" {
    for_each = toset(var.app_names)
    content {
      service_account_id = twingate_service_account.app[access_service.key].id
    }
  }
}
