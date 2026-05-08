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

# Polls the new SSH port until cloud-init has finished writing the sshd
# drop-in, restarted sshd, and sshd is accepting connections. Without this,
# Ansible races cloud-init and fails with "Connection refused".
resource "terraform_data" "ssh_ready" {
  triggers_replace = {
    server_id = hcloud_server.this.id
    ssh_port  = random_integer.ssh_port.result
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = {
      HOST     = hcloud_server.this.ipv4_address
      SSH_PORT = tostring(random_integer.ssh_port.result)
    }
    command = <<-EOT
      set -euo pipefail
      for attempt in $(seq 1 60); do
        keys=$(ssh-keyscan -T 5 -p "$SSH_PORT" "$HOST" 2>/dev/null || true)
        if [ -n "$keys" ]; then
          exit 0
        fi
        sleep 5
      done
      echo "Timed out waiting for sshd on $HOST:$SSH_PORT" >&2
      exit 1
    EOT
  }

  depends_on = [
    hcloud_server.this,
    terraform_data.ssh_agent_loaded,
  ]
}
