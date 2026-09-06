variable "grafana_hostname" {
  description = "Public hostname where the Grafana dashboard is exposed (e.g. grafana.example.com)"
  type        = string
  sensitive   = true
}

variable "victoria_metrics_k8s_stack_chart_version" {
  description = "Helm chart version for VictoriaMetrics/helm-charts victoria-metrics-k8s-stack. The chart pins compatible versions of the VictoriaMetrics operator, VMSingle, VMAgent, VMAlert, Grafana, node-exporter and kube-state-metrics, so only the chart version is exposed here."
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

variable "valid_email" {
  description = "Email address allowed to sign in to Grafana"
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
  description = "PostgreSQL instance in which this module owns the grafana role and schema."
  type = object({
    host        = string
    port        = number
    name        = string
    jdbc_url    = string
    namespace   = string
    deployment  = string
    instance_id = string
    ssh = object({
      host     = string
      port     = number
      username = string
    })
  })
}

variable "wait_for" {
  description = "Optional dependency to wait for before deploying (e.g., ingress controller readiness)"
  type        = string
  default     = null
}

variable "gateway_parent_ref" {
  description = "Shared ingress Gateway reference from setup_ingress_controller.gateway_parent_ref."
  type = object({
    name         = string
    namespace    = string
    section_name = string
  })
}
