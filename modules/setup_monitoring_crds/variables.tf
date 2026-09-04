variable "prometheus_operator_crds_chart_version" {
  description = "Helm chart version for prometheus-community/prometheus-operator-crds. Keep the bundled CRDs compatible with the VictoriaMetrics operator shipped by setup_victoria_metrics."
  type        = string
}

variable "wait_for" {
  description = "Optional dependency to wait for before deploying (e.g., cluster readiness)"
  type        = string
  default     = null
}
