resource "random_password" "initial" {
  length           = 24
  special          = true
  override_special = "-_=+:[]{}"
}

locals {
  cloud_init = templatefile("${path.module}/cloud_init.yaml.tftpl", {
    username = var.username
    password = random_password.initial.result
  })
}

resource "hcloud_server" "this" {
  name        = var.server_name
  server_type = var.server_type
  location    = var.location
  image       = var.image
  user_data   = local.cloud_init
  labels      = var.labels

  lifecycle {
    ignore_changes = [user_data]
  }
}
