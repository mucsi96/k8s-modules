locals {
  grafana_host    = "grafana.${var.dns_zone}"
  prometheus_host = "prometheus.${var.dns_zone}"
  dashboard_host  = "dashboard.${var.dns_zone}"

  grafana_db_url = "postgres://${urlencode(var.postgres_username)}:${urlencode(var.postgres_password)}@${var.postgres_host}:${var.postgres_port}/${var.postgres_database}?sslmode=disable&search_path=${var.grafana_schema}"
}

resource "kubernetes_namespace_v1" "monitoring" {
  metadata {
    name = var.k8s_namespace
  }
}
