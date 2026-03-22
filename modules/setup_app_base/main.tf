module "create_namespace" {
  source                     = "../create_app_namespace"
  environment_name           = var.environment_name
  k8s_namespace              = var.app_name
  k8s_host                   = var.k8s_host
  k8s_cluster_ca_certificate = var.k8s_cluster_ca_certificate
}
