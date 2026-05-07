variable "k8s_namespace" {
  description = "Kubernetes namespace where Loki and Alloy are deployed. Kept separate from 'monitoring' so the log pipeline can be upgraded or torn down independently of the Prometheus/Grafana stack."
  type        = string
  default     = "logging"
}

variable "loki_chart_version" {
  description = "Helm chart version for grafana/loki. The chart pins a compatible appVersion of Loki, so only the chart version is exposed here."
  type        = string
}

variable "alloy_chart_version" {
  description = "Helm chart version for grafana/alloy. The chart pins a compatible appVersion of Alloy, so only the chart version is exposed here."
  type        = string
}

variable "grafana_namespace" {
  description = "Namespace where Grafana (kube-prometheus-stack) is installed. Loki provisions its datasource ConfigMap there so the kiwigrid sidecar discovers it; the sidecar only watches its own release namespace by default."
  type        = string
}

variable "log_retention_period" {
  description = "Loki log retention period (Go duration). The compactor deletes chunks older than this so disk usage on the local filesystem store stays bounded."
  type        = string
  default     = "168h"
}

variable "loki_storage_size" {
  description = "Persistent volume size for Loki's filesystem chunks/index store on the single-binary StatefulSet."
  type        = string
  default     = "20Gi"
}

variable "loki_host_path" {
  description = "Host path on the node used to back Loki's persistent volume. Mirrors the redis and create_postgres_database pattern of pre-creating a hostPath PV."
  type        = string
  default     = "/data/loki"
}

variable "wait_for" {
  description = "Optional dependency to wait for before deploying (e.g., kube-prometheus-stack readiness so the datasource ConfigMap can land in the Grafana namespace)."
  type        = string
  default     = null
}
