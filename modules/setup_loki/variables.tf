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

variable "openobserve_chart_version" {
  description = "Helm chart version for openobserve/openobserve-standalone. OpenObserve is a Splunk-style log viewer with first-class JSON field extraction; it shares the 'logging' namespace with Loki so the two pipelines can be operated together."
  type        = string
}

variable "openobserve_image_version" {
  description = "Container image tag override for openobserve. Leave empty to use the appVersion pinned by the Helm chart."
  type        = string
  default     = ""
}

variable "openobserve_storage_size" {
  description = "Persistent volume size for OpenObserve's local data directory (WAL, index, files store). The single-node deployment keeps everything on disk under ZO_DATA_DIR."
  type        = string
  default     = "20Gi"
}

variable "openobserve_host_path" {
  description = "Host path on the node used to back OpenObserve's persistent volume. Mirrors the Loki/Redis/Postgres pattern of pre-creating a hostPath PV."
  type        = string
  default     = "/data/openobserve"
}

variable "openobserve_hostname" {
  description = "Public hostname where the OpenObserve UI is exposed (e.g. logs.example.com)."
  type        = string
  sensitive   = true
}

variable "tenant_id" {
  description = "Azure AD tenant ID used as the OIDC issuer for oauth2-proxy in front of OpenObserve."
  type        = string
}

variable "openobserve_client_id" {
  description = "OIDC client ID of the Entra application used by oauth2-proxy in front of OpenObserve."
  type        = string
}

variable "openobserve_client_secret" {
  description = "OIDC client secret of the Entra application used by oauth2-proxy in front of OpenObserve."
  type        = string
  sensitive   = true
}

variable "valid_email" {
  description = "Email address allowed to sign in to OpenObserve via Entra. Also used as the OpenObserve root user email so the same identity authenticates at both layers."
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

variable "oauth2_proxy_chart_version" {
  description = "Helm chart version for oauth2-proxy in front of OpenObserve."
  type        = string
}

variable "oauth2_proxy_image_version" {
  description = "Container image tag for oauth2-proxy in front of OpenObserve."
  type        = string
}
