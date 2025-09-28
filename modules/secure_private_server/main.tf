
resource "tls_private_key" "user" {
  algorithm = "ED25519"
}

resource "random_password" "user_password" {
  length           = 20
  special          = true
  override_special = "-_=+:[]{}"
}

resource "ansible_host" "host" {
  name = "private_server"

  variables = {
    ansible_host     = var.host
    ansible_port     = var.initial_port
    ansible_user     = var.username
    ansible_ssh_pass = var.initial_password
  }
}

resource "ansible_playbook" "playbook" {
  name       = "secure_private_server"
  playbook   = "${path.module}/playbook.yaml"
  replayable = true

  extra_vars = {
    username   = var.username
    public_key = tls_private_key.user.public_key_openssh
    password   = random_password.user_password.result
  }
}
