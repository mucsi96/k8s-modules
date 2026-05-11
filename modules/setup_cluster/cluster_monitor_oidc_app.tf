# Entra application that fronts the cluster monitor (Headlamp) dashboard via
# oauth2-proxy. Confidential web client: oauth2-proxy completes the
# authorization-code flow against Entra with this client_id and client_secret,
# and the resulting ID token only proves *who is allowed to open the
# dashboard*. Deliberately distinct from the apiserver Entra app — the
# dashboard does NOT forward the user's token to the apiserver; Headlamp talks
# to the apiserver as its own in-cluster ServiceAccount.
module "cluster_monitor" {
  source = "../register_webapp"

  display_name  = "Cluster monitor - ${var.environment_name}"
  owner         = var.owner
  redirect_uris = var.cluster_monitor_redirect_uris
}
