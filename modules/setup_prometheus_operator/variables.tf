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

variable "grafana_database" {
  description = "PostgreSQL database Grafana stores its dashboards, users, and other state in. Pass values from a setup_postgres_database / create_postgres_database module instance."
  type = object({
    host     = string
    port     = number
    name     = string
    username = string
    password = string
  })
  sensitive = true
}

variable "wait_for" {
  description = "Optional dependency to wait for before deploying (e.g., ingress controller readiness)"
  type        = string
  default     = null
}
