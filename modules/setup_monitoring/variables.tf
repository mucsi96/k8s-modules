variable "environment_name" {
  description = "The name of the environment"
  type        = string
}

variable "dns_zone" {
  description = "The DNS zone used by the cluster (e.g. example.com)"
  type        = string
  sensitive   = true
}

variable "k8s_namespace" {
  description = "Kubernetes namespace for the monitoring stack"
  type        = string
  default     = "monitoring"
}

variable "kube_prometheus_stack_chart_version" {
  description = "Version of the kube-prometheus-stack Helm chart"
  type        = string
  # https://github.com/prometheus-community/helm-charts/releases
  default = "84.5.0"
}

variable "loki_chart_version" {
  description = "Version of the loki Helm chart (singleBinary mode)"
  type        = string
  # https://github.com/grafana/loki/blob/main/production/helm/loki/Chart.yaml
  default = "6.45.0"
}

variable "promtail_chart_version" {
  description = "Version of the promtail Helm chart"
  type        = string
  # https://github.com/grafana/helm-charts/blob/main/charts/promtail/Chart.yaml
  default = "6.21.0"
}

variable "kubernetes_dashboard_chart_version" {
  description = "Version of the kubernetes-dashboard Helm chart"
  type        = string
  # https://github.com/kubernetes/dashboard/releases
  default = "7.14.0"
}

variable "postgres_host" {
  description = "Postgres service host (e.g. postgres1.db)"
  type        = string
}

variable "postgres_port" {
  description = "Postgres port"
  type        = number
  default     = 5432
}

variable "postgres_database" {
  description = "Postgres database name (existing database where the grafana schema lives)"
  type        = string
}

variable "postgres_username" {
  description = "Postgres username with privileges to create the grafana schema and own its objects"
  type        = string
  sensitive   = true
}

variable "postgres_password" {
  description = "Postgres password"
  type        = string
  sensitive   = true
}

variable "grafana_schema" {
  description = "Postgres schema used by Grafana to persist dashboards/users/etc."
  type        = string
  default     = "grafana"
}

variable "cloudflare_account_id" {
  description = "Cloudflare account id"
  type        = string
}

variable "cloudflare_access_policy_id" {
  description = "Cloudflare Zero Trust Access policy id reused for all monitoring apps"
  type        = string
}

variable "cloudflare_identity_provider_id" {
  description = "Cloudflare Zero Trust identity provider id reused for all monitoring apps"
  type        = string
}

variable "wait_for" {
  description = "Optional dependency to wait for before deploying the monitoring stack"
  type        = string
  default     = null
}
