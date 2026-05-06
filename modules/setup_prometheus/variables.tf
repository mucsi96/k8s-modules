variable "prometheus_hostname" {
  description = "Public hostname where the Prometheus UI is exposed (e.g. prometheus.example.com)"
  type        = string
  sensitive   = true
}

variable "grafana_hostname" {
  description = "Public hostname where Grafana is exposed (e.g. grafana.example.com)"
  type        = string
  sensitive   = true
}

variable "session_redis" {
  description = "Redis backend for oauth2-proxy session storage. Pass connection_url and password from a setup_redis module instance."
  type = object({
    connection_url = string
    password       = string
  })
  sensitive = true
}

variable "tenant_id" {
  description = "Azure AD tenant ID used as the OIDC issuer for oauth2-proxy"
  type        = string
}

variable "prometheus_client_id" {
  description = "OIDC client ID of the Entra application protecting the Prometheus UI"
  type        = string
}

variable "prometheus_client_secret" {
  description = "OIDC client secret of the Entra application protecting the Prometheus UI"
  type        = string
  sensitive   = true
}

variable "grafana_client_id" {
  description = "OIDC client ID of the Entra application protecting Grafana"
  type        = string
}

variable "grafana_client_secret" {
  description = "OIDC client secret of the Entra application protecting Grafana"
  type        = string
  sensitive   = true
}

variable "valid_email" {
  description = "Email address allowed to sign in to Prometheus and Grafana"
  type        = string
  sensitive   = true
}

variable "kube_prometheus_stack_chart_version" {
  description = "Helm chart version for prometheus-community/kube-prometheus-stack"
  type        = string
}

variable "prometheus_image_version" {
  description = "Container image tag for the Prometheus server"
  type        = string
}

variable "alertmanager_image_version" {
  description = "Container image tag for Alertmanager"
  type        = string
}

variable "grafana_image_version" {
  description = "Container image tag for Grafana"
  type        = string
}

variable "prometheus_blackbox_exporter_chart_version" {
  description = "Helm chart version for prometheus-community/prometheus-blackbox-exporter"
  type        = string
}

variable "prometheus_blackbox_exporter_image_version" {
  description = "Container image tag for blackbox-exporter"
  type        = string
}

variable "prometheus_adapter_chart_version" {
  description = "Helm chart version for prometheus-community/prometheus-adapter"
  type        = string
}

variable "prometheus_adapter_image_version" {
  description = "Container image tag for prometheus-adapter"
  type        = string
}

variable "oauth2_proxy_chart_version" {
  description = "Helm chart version for oauth2-proxy"
  type        = string
}

variable "oauth2_proxy_image_version" {
  description = "Container image tag for oauth2-proxy"
  type        = string
}

variable "grafana_database" {
  description = "PostgreSQL backend used by Grafana to store dashboards, users and other internal state."
  type = object({
    host     = string
    port     = number
    name     = string
    user     = string
    password = string
  })
  sensitive = true
}

variable "wait_for" {
  description = "Optional dependency to wait for before deploying (e.g., ingress controller readiness)"
  type        = string
  default     = null
}
