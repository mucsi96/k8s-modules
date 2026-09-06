output "jdbc_url" {
  value = "jdbc:postgresql://${var.k8s_name}.${var.k8s_namespace}:5432/${var.db_name}"
}

output "namespace" {
  description = "Namespace containing PostgreSQL and its administrator Secret."
  value       = var.k8s_namespace
}

output "admin_secret_name" {
  description = "Name of the database-namespace Secret used only by schema provisioning Jobs."
  value       = helm_release.database.name
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
