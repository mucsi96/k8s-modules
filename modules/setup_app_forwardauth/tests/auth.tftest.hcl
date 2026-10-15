mock_provider "helm" {}
mock_provider "kubernetes" {}
mock_provider "random" {}

override_resource {
  target = random_password.cookie
  values = { result = "fixturecookiekey0123456789abcdef" }
}

variables {
  name                = "hello"
  namespace           = "hello"
  hostname            = "hello.example.test"
  tenant_id           = "10000000-0000-0000-0000-000000000001"
  client_id           = "10000000-0000-0000-0000-000000000002"
  client_secret       = "fixture-web-secret"
  api_client_id       = "10000000-0000-0000-0000-000000000003"
  chart_version       = "1.0.0"
  trusted_proxy_cidrs = ["10.42.0.0/16"]
  session_redis       = { connection_url = "redis://redis.redis.svc.cluster.local:6379", password = "fixture-redis-secret" }
  gateway_parent_ref  = { name = "traefik", namespace = "traefik", section_name = "websecure" }
  protected_apps = {
    hello-client = { port = 8000 }
    hello-server = { port = 8080, management_port = 8082 }
  }
}

run "secret_references_and_ingress_boundary" {
  command = plan
  assert {
    condition     = helm_release.auth.chart == "oauth2-proxy-forwardauth" && helm_release.auth.version == var.chart_version
    error_message = "The platform must pin the integration chart version."
  }
  assert {
    condition     = kubernetes_secret_v1.credentials.data["client-secret"] == var.client_secret && kubernetes_secret_v1.redis.data["redis-password"] == var.session_redis.password
    error_message = "Runtime credentials must remain in their distinct Secrets."
  }
  assert {
    condition     = length(kubernetes_network_policy_v1.app["hello-server"].spec[0].ingress) == 2 && length(kubernetes_network_policy_v1.app["hello-client"].spec[0].ingress) == 1
    error_message = "Only the API management port must add monitoring ingress."
  }
  assert {
    condition     = kubernetes_network_policy_v1.app["hello-server"].spec[0].ingress[0].from[0].pod_selector[0].match_labels["app.kubernetes.io/name"] == "traefik"
    error_message = "Browser app ports must admit only Traefik."
  }
}
