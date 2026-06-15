resource "terraform_data" "wait_for" {
  input = var.wait_for
}

# Install the Prometheus Operator CRDs (ServiceMonitor, PodMonitor,
# PrometheusRule, ...) on their own, ahead of any chart that ships those
# resources. The full kube-prometheus-stack (setup_prometheus_operator) cannot
# do this job early: it depends on the shared Postgres for Grafana's metadata,
# so it must run after create_postgres_database. But the postgres-db chart now
# ships a ServiceMonitor, which needs these CRDs to already exist. Installing
# them from the dedicated prometheus-operator-crds chart here breaks that
# ordering cycle; kube-prometheus-stack then runs with crds.enabled = false so
# it does not try to template or re-own the same CRDs.
#
# The chart contains only cluster-scoped CRDs, so the release is parked in
# kube-system (which always exists) to avoid contending for ownership of the
# monitoring namespace that setup_prometheus_operator manages.
resource "helm_release" "prometheus_operator_crds" {
  name       = "prometheus-operator-crds"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus-operator-crds"
  version    = var.prometheus_operator_crds_chart_version
  namespace  = "kube-system"
  wait       = true
  timeout    = 600

  depends_on = [terraform_data.wait_for]
}
