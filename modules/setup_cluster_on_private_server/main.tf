
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
}

resource "terraform_data" "known_hosts_entry" {
  provisioner "local-exec" {
    command = "ssh-keyscan -H ${var.host} >> ~/.ssh/known_hosts"
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

# resource "ansible_playbook" "test_connection" {
#   name       = var.host
#   playbook   = "${path.module}/test_connection.yaml"
#   replayable = false

#   extra_vars = {
#     ansible_python_interpreter = "/usr/bin/python3"
#     ansible_port               = tostring(random_integer.ssh_port.result)
#     ansible_user               = var.username
#     ansible_become_password    = random_password.root_password.result
#     ansible
#   }

#   depends_on = [ansible_playbook.secure_private_server]

# }
