resource "random_password" "initial_password" {
  length  = 20
  special = false
}

resource "tls_private_key" "provisioner" {
  algorithm = "ED25519"
}

resource "hcloud_ssh_key" "provisioner" {
  name       = "${var.name}-provisioner"
  public_key = tls_private_key.provisioner.public_key_openssh
}

resource "hcloud_server" "this" {
  name        = var.name
  server_type = var.server_type
  location    = var.location
  image       = var.image
  ssh_keys    = [hcloud_ssh_key.provisioner.id]

  user_data = <<-YAML
    #cloud-config
    users:
      - name: ${var.username}
        groups: sudo
        shell: /bin/bash
        lock_passwd: false
    chpasswd:
      list: |
        ${var.username}:${random_password.initial_password.result}
      expire: false
    ssh_pwauth: true
  YAML
}

resource "terraform_data" "wait_for_cloud_init" {
  triggers_replace = {
    server_id = hcloud_server.this.id
  }

  provisioner "remote-exec" {
    inline = ["cloud-init status --wait"]
    connection {
      type        = "ssh"
      host        = hcloud_server.this.ipv4_address
      user        = "root"
      private_key = tls_private_key.provisioner.private_key_openssh
      timeout     = "5m"
    }
  }
}
