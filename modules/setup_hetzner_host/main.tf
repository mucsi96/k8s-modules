resource "tls_private_key" "bootstrap" {
  algorithm = "ED25519"
}

resource "random_password" "bootstrap" {
  length           = 20
  special          = true
  override_special = "-_=+:[]{}"
}

resource "hcloud_ssh_key" "bootstrap" {
  name       = "${var.server_name}-bootstrap"
  public_key = tls_private_key.bootstrap.public_key_openssh
}

locals {
  bootstrap_password_hash = bcrypt(random_password.bootstrap.result)
}

resource "hcloud_server" "this" {
  name        = var.server_name
  location    = var.location
  server_type = var.server_type
  image       = var.image
  ssh_keys    = [hcloud_ssh_key.bootstrap.id]

  user_data = <<-EOT
    #cloud-config
    users:
      - default
      - name: ${var.ssh_username}
        shell: /bin/bash
        sudo: ALL=(ALL) NOPASSWD:ALL
        lock_passwd: false
        passwd: ${local.bootstrap_password_hash}
    ssh_pwauth: true
  EOT
}
