resource "tls_private_key" "user" {
  algorithm = "ED25519"
}

resource "random_integer" "ssh_port" {
  min = 2000
  max = 65000
}

locals {
  private_key_path = "${path.module}/.generated/${var.server_name}-id_ed25519"

  cloud_init = templatefile("${path.module}/cloud_init.yaml.tftpl", {
    username       = var.username
    ssh_public_key = trimspace(tls_private_key.user.public_key_openssh)
    ssh_port       = random_integer.ssh_port.result
  })
}

# terraform_data + local-exec writes the SSH private key to disk so Ansible
# playbooks can reference it via path. Using terraform_data instead of
# local_sensitive_file because the local provider drops the resource from state
# whenever the file is absent on disk, forcing replays on every apply.
resource "terraform_data" "user_private_key" {
  input = local.private_key_path

  triggers_replace = {
    key_id   = tls_private_key.user.id
    filename = local.private_key_path
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail
      install -m 0700 -d "$(dirname "$KEY_FILE")"
      umask 077
      printf '%s' "$SSH_KEY" > "$KEY_FILE"
      chmod 0600 "$KEY_FILE"
    EOT
    environment = {
      SSH_KEY  = tls_private_key.user.private_key_openssh
      KEY_FILE = local.private_key_path
    }
  }
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

resource "terraform_data" "known_hosts_entry" {
  triggers_replace = {
    host     = hcloud_server.this.ipv4_address
    ssh_port = random_integer.ssh_port.result
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = {
      HOST     = hcloud_server.this.ipv4_address
      SSH_PORT = tostring(random_integer.ssh_port.result)
    }
    command = <<-EOT
      set -euo pipefail
      mkdir -p ~/.ssh
      chmod 700 ~/.ssh
      touch ~/.ssh/known_hosts
      chmod 600 ~/.ssh/known_hosts
      ssh-keygen -R "[$HOST]:$SSH_PORT" >/dev/null 2>&1 || true
      for attempt in $(seq 1 60); do
        scan=$(ssh-keyscan -H -T 5 -p "$SSH_PORT" "$HOST" 2>/dev/null || true)
        if [ -n "$scan" ]; then
          printf '%s\n' "$scan" >> ~/.ssh/known_hosts
          exit 0
        fi
        sleep 5
      done
      echo "Timed out waiting for SSH on $HOST:$SSH_PORT" >&2
      exit 1
    EOT
  }
}
