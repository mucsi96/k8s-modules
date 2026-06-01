variable "k8s_namespace" {
  description = "Namespace where the Faro receiver (Alloy) is deployed. Defaults to 'monitoring' so it sits alongside Grafana/Prometheus, which is also where the auto-loaded dashboard ConfigMap needs to live."
  type        = string
  default     = "monitoring"
}

variable "grafana_namespace" {
  description = "Namespace where Grafana (kube-prometheus-stack) is installed. The Loki-backed logs dashboard ConfigMap is created here so the kiwigrid sidecar discovers it; the sidecar only watches its own release namespace by default."
  type        = string
}

variable "alloy_chart_version" {
  description = "Helm chart version for grafana/alloy. Alloy is reused here as a Faro receiver — separate from the DaemonSet that scrapes node pod logs in the logging namespace."
  type        = string
}

variable "loki_url" {
  description = "In-cluster base URL of the Loki HTTP API (e.g. http://loki.logging.svc.cluster.local:3100). Faro receiver forwards browser logs to <loki_url>/loki/api/v1/push."
  type        = string
}

variable "hostname" {
  description = "Public hostname where the Faro receiver is exposed (e.g. faro.example.com). Browsers running the Faro Web SDK POST telemetry to https://<hostname>/collect."
  type        = string
  sensitive   = true
}

variable "cors_allowed_origins" {
  description = "Origins permitted to push to the Faro receiver. Defaults to '*' so any SPA can ship logs; lock this down to the specific app origins for a tighter trust boundary."
  type        = list(string)
  default     = ["*"]
}

variable "rate_limit_rps" {
  description = "Maximum requests-per-second the Faro receiver accepts before shedding. Protects against a buggy SPA or hostile client flooding Loki."
  type        = number
  default     = 50
}

variable "rate_limit_burst" {
  description = "Burst size for the Faro receiver's token-bucket rate limiter."
  type        = number
  default     = 100
}

variable "wait_for" {
  description = "Optional dependency to wait for before deploying (Loki readiness so the receiver has somewhere to push, plus kube-prometheus-stack so the dashboard ConfigMap is picked up)."
  type        = string
  default     = null
}
