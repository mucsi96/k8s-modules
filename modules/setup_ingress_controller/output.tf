output "hostname" {
  value = "${var.resource_group_name}.${var.dns_zone}"
}