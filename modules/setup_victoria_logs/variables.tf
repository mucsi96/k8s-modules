variable "k8s_namespace" {
  description = "Kubernetes namespace where Alloy (pod log collection + Faro receiver) is deployed. Kept separate from 'monitoring' so the log pipeline can be upgraded or torn down independently of the VictoriaMetrics/Grafana stack."
  type        = string
  default     = "logging"
}

variable "alloy_chart_version" {
  description = "Helm chart version for grafana/alloy. The chart pins a compatible appVersion of Alloy, so only the chart version is exposed here."
  type        = string
}

variable "victoria_logs_url" {
  description = "In-cluster base URL of the VLSingle HTTP API owned by setup_prometheus_operator (e.g. http://vlsingle-victoria-metrics-k8s-stack.monitoring.svc.cluster.local:9428). Alloy's loki.write appends the Loki-compatible /insert/loki/api/v1/push path."
  type        = string
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
  description = "Maximum requests-per-second the Faro receiver accepts before shedding. Protects against a buggy SPA or hostile client flooding VictoriaLogs."
  type        = number
  default     = 50
}

variable "faro_rate_limit_burst" {
  description = "Burst size for the Faro receiver's token-bucket rate limiter."
  type        = number
  default     = 100
}

variable "wait_for" {
  description = "Optional dependency to wait for before deploying (e.g., victoria-metrics-k8s-stack readiness so VLSingle exists before Alloy starts pushing logs to it)."
  type        = string
  default     = null
}
