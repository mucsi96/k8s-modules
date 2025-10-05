
resource "tls_private_key" "user" {
  algorithm = "ED25519"
}

resource "random_password" "user_password" {
  length           = 20
  special          = true
  override_special = "-_=+:[]{}"
}

resource "random_password" "root_password" {
  length           = 20
  special          = true
  override_special = "-_=+:[]{}"
}

resource "random_integer" "ssh_port" {
  min = 2000
  max = 65000
}

resource "local_sensitive_file" "user_private_key" {
  content              = tls_private_key.user.private_key_openssh
  file_permission      = "0600"
  directory_permission = "0700"
  filename             = "${path.module}/.generated/${var.host}-id_ed25519"

  depends_on = [var.host]
}

resource "terraform_data" "known_hosts_entry" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-lc"]
    command     = <<-EOT
      ssh-keyscan -H ${var.host} -p ${var.initial_port} >> ~/.ssh/known_hosts || ssh-keyscan -p ${random_integer.ssh_port.result} -H ${var.host} >> ~/.ssh/known_hosts
    EOT
  }

  triggers_replace = {
    host = var.host
  }
}

resource "ansible_playbook" "secure_private_server" {
  name       = var.host
  playbook   = "${path.module}/secure_private_server.yaml"
  replayable = false

  extra_vars = {
    ansible_python_interpreter = "/usr/bin/python3"
    ansible_port               = var.initial_port
    ansible_user               = var.username
    ansible_become_password    = var.initial_password
    ansible_ssh_pass           = var.initial_password

    public_key        = tls_private_key.user.public_key_openssh
    password          = random_password.user_password.result
    new_root_password = random_password.root_password.result
    ssh_port          = tostring(random_integer.ssh_port.result)
  }

  depends_on = [terraform_data.known_hosts_entry]
}

resource "ansible_playbook" "firewall" {
  name       = var.host
  playbook   = "${path.module}/firewall.yaml"
  replayable = false

  extra_vars = {
    ansible_python_interpreter   = "/usr/bin/python3"
    ansible_port                 = tostring(random_integer.ssh_port.result)
    ansible_user                 = var.username
    ansible_become_password      = random_password.user_password.result
    ansible_ssh_private_key_file = local_sensitive_file.user_private_key.filename

    ssh_port            = tostring(random_integer.ssh_port.result)
    kubernetes_api_port = "6443"
  }

  depends_on = [ansible_playbook.secure_private_server]
}

resource "ansible_playbook" "system_update" {
  name       = var.host
  playbook   = "${path.module}/system_update.yaml"
  replayable = false

  extra_vars = {
    ansible_python_interpreter   = "/usr/bin/python3"
    ansible_port                 = tostring(random_integer.ssh_port.result)
    ansible_user                 = var.username
    ansible_become_password      = random_password.user_password.result
    ansible_ssh_private_key_file = local_sensitive_file.user_private_key.filename
  }

  depends_on = [ansible_playbook.firewall]
}

resource "terraform_data" "wait_for_system" {
  triggers_replace = {
    last_run = ansible_playbook.system_update.id
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Server reachable after updates'",
    ]

    connection {
      type        = "ssh"
      host        = var.host
      port        = random_integer.ssh_port.result
      user        = var.username
      private_key = tls_private_key.user.private_key_openssh
      timeout     = "10m"
      agent       = false
    }
  }

  depends_on = [ansible_playbook.system_update]
}

resource "ansible_playbook" "install_microk8s" {
  name       = var.host
  playbook   = "${path.module}/install_microk8s.yaml"
  replayable = false

  extra_vars = {
    ansible_python_interpreter   = "/usr/bin/python3"
    ansible_port                 = tostring(random_integer.ssh_port.result)
    ansible_user                 = var.username
    ansible_become_password      = random_password.user_password.result
    ansible_ssh_private_key_file = local_sensitive_file.user_private_key.filename
  }

  depends_on = [terraform_data.wait_for_system]
}

resource "terraform_data" "fetch_microk8s_config" {
  triggers_replace = {
    host             = var.host
    ssh_port         = tostring(random_integer.ssh_port.result)
    username         = var.username
    key_hash         = sha256(tls_private_key.user.public_key_openssh)
    microk8s_channel = "1.30/stable"
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-lc"]
    command     = <<-EOT
      set -euo pipefail
      mkdir -p ${path.root}/.kube
      scp -i ${local_sensitive_file.user_private_key.filename} \
        -P ${random_integer.ssh_port.result} \
        ${var.username}@${var.host}:/home/${var.username}/microk8s-admin.conf \
        ${path.root}/.kube/admin-config
      chmod 600 ${path.root}/.kube/admin-config
    EOT
  }

  depends_on = [ansible_playbook.install_microk8s]
}


data "local_file" "kube_admin_config" {
  filename   = "${path.root}/.kube/admin-config"
  depends_on = [terraform_data.fetch_microk8s_config]
}
