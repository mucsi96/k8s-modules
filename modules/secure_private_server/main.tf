
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

resource "ansible_playbook" "playbook" {
  name       = var.host
  playbook   = "${path.module}/playbook.yaml"
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
}
