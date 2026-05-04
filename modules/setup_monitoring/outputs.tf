output "k8s_namespace" {
  value       = kubernetes_namespace_v1.monitoring.metadata[0].name
  description = "Namespace where the monitoring stack is deployed"
}

output "grafana_host" {
  value       = local.grafana_host
  description = "Public hostname for Grafana"
}

output "prometheus_host" {
  value       = local.prometheus_host
  description = "Public hostname for Prometheus"
}

output "kubernetes_dashboard_host" {
  value       = local.dashboard_host
  description = "Public hostname for the Kubernetes Dashboard"
}

output "grafana_backup_config" {
  description = "Backup config entry for the Grafana Postgres schema. Pass into setup_backup_app.additional_dbs."
  value = {
    name            = "Grafana"
    host            = var.postgres_host
    port            = var.postgres_port
    database        = var.postgres_database
    schema          = var.grafana_schema
    username        = var.postgres_username
    password        = var.postgres_password
    createPlainDump = true
    folderBackups   = []
    excludeTables   = []
  }
  sensitive = true
}
