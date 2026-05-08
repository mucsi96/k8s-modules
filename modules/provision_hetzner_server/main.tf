resource "tls_private_key" "user" {
  algorithm = "ED25519"
}

resource "random_integer" "ssh_port" {
  min = 2000
  max = 65000
}

locals {
  cloud_init = templatefile("${path.module}/cloud_init.yaml.tftpl", {
    username       = var.username
    ssh_public_key = trimspace(tls_private_key.user.public_key_openssh)
    ssh_port       = random_integer.ssh_port.result
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

# Loads the generated private key into the caller's ssh-agent. The key is
# piped via stdin from an env var, so it never touches the local filesystem.
# The agent (and therefore SSH_AUTH_SOCK) must be started by the caller, e.g.
# `eval "$(ssh-agent -s)"` in scripts/create.sh, before `terraform apply`.
resource "terraform_data" "ssh_agent_loaded" {
  triggers_replace = {
    key_id = tls_private_key.user.id
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = {
      SSH_KEY = tls_private_key.user.private_key_openssh
    }
    command = <<-EOT
      set -euo pipefail
      if [ -z "$${SSH_AUTH_SOCK:-}" ]; then
        echo "SSH_AUTH_SOCK is not set. Run terraform via scripts/create.sh, or" >&2
        echo "start an ssh-agent yourself before applying:" >&2
        echo "    eval \"\$(ssh-agent -s)\"" >&2
        exit 1
      fi
      printf '%s\n' "$SSH_KEY" | ssh-add - >/dev/null
    EOT
  }

  depends_on = [hcloud_server.this]
}
