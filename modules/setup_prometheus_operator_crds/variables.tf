variable "prometheus_operator_crds_chart_version" {
  description = "Helm chart version for prometheus-community/prometheus-operator-crds. Keep the bundled CRDs in sync with the Prometheus Operator version shipped by the kube-prometheus-stack chart used in setup_prometheus_operator."
  type        = string
}

variable "wait_for" {
  description = "Optional dependency to wait for before deploying (e.g., cluster readiness)"
  type        = string
  default     = null
}
