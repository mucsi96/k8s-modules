# Confidential OIDC web client for the cluster monitor (Headlamp) dashboard.
# oauth2-proxy completes the auth-code flow against Entra with this
# client_id/client_secret and uses the resulting session purely to gate
# access to the dashboard UI — the id_token is NOT forwarded to the
# apiserver. Headlamp talks to the apiserver as its in-cluster
# ServiceAccount (bound to `view` by the helm chart), which caps any
# operator's dashboard view at read-only regardless of their kubectl-side
# RBAC. The apiserver trusts a separate audience (see apiserver_oidc_app.tf).
module "cluster_monitor" {
  source = "../register_webapp"

  display_name  = "Cluster monitor - ${var.environment_name}"
  owner         = var.owner
  redirect_uris = var.cluster_monitor_redirect_uris
}
