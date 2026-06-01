variable "grafana_hostname" {
  description = "Public hostname where the Grafana dashboard is exposed (e.g. grafana.example.com)"
  type        = string
  sensitive   = true
}

variable "prometheus_hostname" {
  description = "Public hostname where the Prometheus UI is exposed (e.g. prometheus.example.com)"
  type        = string
  sensitive   = true
}

variable "kube_prometheus_stack_chart_version" {
  description = "Helm chart version for prometheus-community/kube-prometheus-stack. The chart pins compatible versions of the Prometheus Operator, Prometheus, Alertmanager, Grafana, node-exporter and kube-state-metrics, so only the chart version is exposed here."
  type        = string
}

variable "tenant_id" {
  description = "Azure AD tenant ID used as the OIDC issuer for oauth2-proxy"
  type        = string
}

variable "grafana_client_id" {
  description = "OIDC client ID of the Entra application used by Grafana's oauth2-proxy"
  type        = string
}

variable "grafana_client_secret" {
  description = "OIDC client secret of the Entra application used by Grafana's oauth2-proxy"
  type        = string
  sensitive   = true
}

variable "prometheus_client_id" {
  description = "OIDC client ID of the Entra application used by Prometheus's oauth2-proxy"
  type        = string
}

variable "prometheus_client_secret" {
  description = "OIDC client secret of the Entra application used by Prometheus's oauth2-proxy"
  type        = string
  sensitive   = true
}

variable "valid_email" {
  description = "Email address allowed to sign in to the Grafana and Prometheus dashboards"
  type        = string
  sensitive   = true
}

variable "oauth2_proxy_chart_version" {
  description = "Helm chart version for oauth2-proxy"
  type        = string
}

variable "oauth2_proxy_image_version" {
  description = "Container image tag for oauth2-proxy"
  type        = string
}

variable "session_redis" {
  description = "Redis backend for oauth2-proxy session storage. Pass connection_url and password from a setup_redis module instance."
  type = object({
    connection_url = string
    password       = string
  })
  sensitive = true
}

variable "database" {
  description = "PostgreSQL instance Grafana stores its state in. Grafana shares the database with other apps but writes to a dedicated 'grafana' schema owned by a dedicated 'grafana' role created at apply time. Pass admin credentials from a create_postgres_database module instance so the role and schema can be provisioned."
  type = object({
    host           = string
    port           = number
    name           = string
    admin_username = string
    admin_password = string
  })
  sensitive = true
}

variable "faro_hostname" {
  description = "Public hostname where the Grafana Faro receiver is exposed (e.g. faro.example.com). Browsers running the Faro Web SDK POST telemetry to https://<hostname>/collect."
  type        = string
  sensitive   = true
}

variable "faro_alloy_chart_version" {
  description = "Helm chart version for grafana/alloy used by the Faro receiver. Kept separate from the chart version used by setup_loki's pod-log DaemonSet so the two can be upgraded independently."
  type        = string
}

variable "faro_loki_url" {
  description = "In-cluster base URL of the Loki HTTP API the Faro receiver forwards to (e.g. http://loki.logging.svc.cluster.local:3100). Passed as a literal rather than referenced from setup_loki to avoid a dependency cycle (setup_loki depends on this module's kube-prometheus-stack readiness)."
  type        = string
}

variable "faro_cors_allowed_origins" {
  description = "Origins permitted to push to the Faro receiver. Defaults to '*' so any SPA can ship logs; lock this down to specific app origins for a tighter trust boundary."
  type        = list(string)
  default     = ["*"]
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
  description = "Optional dependency to wait for before deploying (e.g., ingress controller readiness)"
  type        = string
  default     = null
}
