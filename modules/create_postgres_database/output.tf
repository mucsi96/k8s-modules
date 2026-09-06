output "jdbc_url" {
  value = "jdbc:postgresql://${var.k8s_name}.${var.k8s_namespace}:5432/${var.db_name}"
}

output "namespace" {
  description = "Namespace containing PostgreSQL."
  value       = var.k8s_namespace
}

output "deployment" {
  description = "PostgreSQL deployment and container name, available after the Helm release is ready."
  value       = helm_release.database.name
}

output "instance_id" {
  description = "Storage resource UID; a recreated volume or cluster reruns schema provisioning."
  value       = kubernetes_persistent_volume_v1.database_pv.metadata[0].uid
}

output "host" {
  description = "In-cluster DNS name of the database Service"
  value       = "${var.k8s_name}.${var.k8s_namespace}"
}

output "port" {
  description = "TCP port the database Service listens on"
  value       = 5432
}

output "name" {
  description = "Name of the database created inside the Postgres instance"
  value       = var.db_name
}
