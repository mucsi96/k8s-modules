resource "random_password" "admin" {
  length           = 24
  special          = true
  min_upper        = 1
  min_lower        = 1
  min_numeric      = 1
  min_special      = 1
  override_special = "-_+=!@#%"
}

resource "hcloud_server" "vm" {
  name        = var.name
  image       = "ubuntu-24.04"
  server_type = "cx22"

  user_data = <<-CLOUDCFG
    #cloud-config
    ssh_pwauth: true
    users:
      - name: ${var.ssh_user}
        groups: [sudo]
        shell: /bin/bash
        sudo: "ALL=(ALL) NOPASSWD:ALL"
    chpasswd:
      list: |
        ${var.ssh_user}:${random_password.admin.result}
      expire: false
  CLOUDCFG

  # Ensure Terraform waits for the VM to accept SSH connections before finishing apply
  provisioner "remote-exec" {
    inline = [
      "echo 'SSH is ready'",
    ]

    connection {
      type     = "ssh"
      host     = self.ipv4_address
      user     = var.ssh_user
      password = random_password.admin.result
      timeout  = "5m"
    }
  }
}

# resource "hcloud_server" "testing_vm" {
#   name        = var.name
#   server_type = var.vm_size
#   image       = "ubuntu-24.04"
#   location    = var.azure_location
#   ssh_keys    = [var.ssh_key_fingerprint]

#   user_data = <<-EOF
#               #cloud-config
#               users:
#                 - name: ${var.admin_username}
#                   sudo: ALL=(ALL) NOPASSWD:ALL
#                   lock_passwd: false
#                   passwd: ${chomp(base64encode(random_password.admin.result))}
#                   ssh_pwauth: true
#                   shell: /bin/bash
#               EOF

#   depends_on = [random_password.admin]
# }
