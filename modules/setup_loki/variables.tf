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

variable "faro_hostname" {
  description = "Public hostname where the Grafana Faro receiver is exposed (e.g. faro.example.com). Browsers running the Faro Web SDK POST telemetry to https://<hostname>/collect."
  type        = string
  sensitive   = true
}

variable "faro_cors_allowed_origins" {
  description = "Origins permitted to push to the Faro receiver. Required with no default so callers cannot accidentally inherit a wildcard — pass the explicit list of SPA origins (production hostnames + any dev origins) that should be able to ship telemetry."
  type        = list(string)
}

variable "faro_rate_limit_rps" {
  description = "Maximum requests-per-second the Faro receiver accepts before shedding. Protects against a buggy SPA or hostile client flooding Loki."
  type        = number
  default     = 50
}

variable "faro_rate_limit_burst" {
  description = "Burst size for the Faro receiver's token-bucket rate limiter."
  type        = number
  default     = 100
}

variable "wait_for" {
  description = "Optional dependency to wait for before deploying (e.g., kube-prometheus-stack readiness so the datasource ConfigMap can land in the Grafana namespace)."
  type        = string
  default     = null
}
