output "crds_ready" {
  description = "Monitoring CRDs Helm release status. Pass as wait_for to modules that ship monitoring.coreos.com resources (e.g. the ServiceMonitor in create_postgres_database) so they only deploy once the CRDs exist."
  value       = helm_release.monitoring_crds.status
}
