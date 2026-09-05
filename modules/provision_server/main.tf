resource "tls_private_key" "user" {
  algorithm = "ED25519"
}

resource "tls_private_key" "install_approval" {
  algorithm = "ED25519"
}

resource "random_integer" "ssh_port" {
  min = 2000
  max = 65000
}

resource "random_password" "user" {
  length      = 32
  min_lower   = 1
  min_numeric = 1
  min_upper   = 1
}

locals {
  netcup_client_id = "scp"
  netcup_token_url = "https://www.servercontrolpanel.de/realms/scp/protocol/openid-connect/token"
}

data "external" "netcup_token" {
  program = ["bash", "${path.module}/netcup_auth.sh"]

  query = {
    client_id     = local.netcup_client_id
    token_url     = local.netcup_token_url
    refresh_token = var.netcup_refresh_token
  }
}

locals {
  netcup_access_token  = sensitive(data.external.netcup_token.result.access_token)
  netcup_refresh_token = sensitive(data.external.netcup_token.result.refresh_token)

  netcup_headers = {
    Accept        = "application/json"
    Authorization = "Bearer ${local.netcup_access_token}"
  }

  bootstrap_script = templatefile("${path.module}/bootstrap.sh.tftpl", {
    username                      = var.username
    ssh_public_key_base64         = base64encode(trimspace(tls_private_key.user.public_key_openssh))
    ssh_port                      = random_integer.ssh_port.result
    twingate_network_base64       = base64encode(var.twingate_network)
    twingate_access_token_base64  = base64encode(var.twingate_access_token)
    twingate_refresh_token_base64 = base64encode(var.twingate_refresh_token)
  })
}

data "http" "server" {
  url             = "${trimsuffix(var.netcup_api_url, "/")}/api/v1/servers/${var.netcup_server_id}"
  request_headers = local.netcup_headers

  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "The Netcup SCP API did not return the requested server."
    }
  }
}

data "http" "image_flavours" {
  url             = "${trimsuffix(var.netcup_api_url, "/")}/api/v1/servers/${var.netcup_server_id}/imageflavours"
  request_headers = local.netcup_headers
}

data "http" "disks" {
  url             = "${trimsuffix(var.netcup_api_url, "/")}/api/v1/servers/${var.netcup_server_id}/disks"
  request_headers = local.netcup_headers
}

locals {
  server         = jsondecode(data.http.server.response_body)
  image_flavours = jsondecode(data.http.image_flavours.response_body)
  disks          = jsondecode(data.http.disks.response_body)

  selected_image_flavours = [
    for image in local.image_flavours : image
    if image.id == var.netcup_image_flavour_id
  ]
  selected_image_description = length(local.selected_image_flavours) == 1 ? lower(join(" ", compact([
    try(local.selected_image_flavours[0].name, ""),
    try(local.selected_image_flavours[0].alias, ""),
    try(local.selected_image_flavours[0].text, ""),
    try(local.selected_image_flavours[0].image.name, ""),
  ]))) : ""
  matching_disks = [
    for disk in local.disks : disk
    if try(disk.name, try(disk.dev, "")) == var.netcup_disk_name
  ]
  public_interfaces = [
    for interface in try(local.server.serverLiveInfo.interfaces, []) : interface
    if !try(interface.vlanInterface, false)
  ]
  interface_mac = try(coalesce(var.netcup_interface_mac, local.public_interfaces[0].mac), "")

  ssh_key_name = "${var.server_name}-${substr(tls_private_key.user.id, 0, 12)}"
  ssh_key_body = jsonencode({
    name = local.ssh_key_name
    key  = trimspace(tls_private_key.user.public_key_openssh)
  })
  install_approval_name = "${var.server_name}-install-${substr(nonsensitive(sha256(var.reinstall_generation)), 0, 12)}"
  install_approval_body = jsonencode({
    name = local.install_approval_name
    key  = trimspace(tls_private_key.install_approval.public_key_openssh)
  })
  image_body = jsonencode({
    imageFlavourId            = var.netcup_image_flavour_id
    diskName                  = var.netcup_disk_name
    rootPartitionFullDiskSize = true
    hostname                  = var.server_name
    locale                    = "en_US.UTF-8"
    timezone                  = "UTC"
    additionalUserUsername    = var.username
    additionalUserPassword    = random_password.user.result
    sshPasswordAuthentication = false
    customScript              = local.bootstrap_script
    emailToExecutingUser      = true
  })
}

# The hashicorp/http provider intentionally has no managed resources. The
# installation is therefore an apply-only terraform_data action: it creates the
# generated SCP SSH key, starts the destructive image task, and polls it to a
# terminal state. A changed reinstall_generation is the explicit reinstall
# control; normal refresh and plan operations never issue a POST.
resource "terraform_data" "debian_install" {
  triggers_replace = {
    server_id            = tostring(var.netcup_server_id)
    image_flavour_id     = tostring(var.netcup_image_flavour_id)
    disk_name            = var.netcup_disk_name
    bootstrap_sha256     = nonsensitive(sha256(local.bootstrap_script))
    reinstall_generation = nonsensitive(sha256(var.reinstall_generation))
  }

  lifecycle {
    precondition {
      condition     = strcontains(lower(try(local.server.template.name, "")), "rs 1000 g12")
      error_message = "netcup_server_id must identify an RS 1000 G12 contract."
    }

    precondition {
      condition     = length(local.selected_image_flavours) == 1 && strcontains(local.selected_image_description, "debian 13")
      error_message = "netcup_image_flavour_id must select an available Debian 13 image flavour."
    }

    precondition {
      condition     = length(local.matching_disks) == 1
      error_message = "netcup_disk_name must match exactly one disk returned by the SCP API."
    }
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = {
      NETCUP_API_URL          = trimsuffix(var.netcup_api_url, "/")
      NETCUP_CLIENT_ID        = local.netcup_client_id
      NETCUP_TOKEN_URL        = local.netcup_token_url
      NETCUP_TOKEN            = local.netcup_access_token
      NETCUP_TOKEN_REFRESH_AT = data.external.netcup_token.result.refresh_at
      NETCUP_REFRESH_TOKEN    = local.netcup_refresh_token
      NETCUP_USER_ID          = tostring(var.netcup_user_id)
      SERVER_ID               = tostring(var.netcup_server_id)
      SSH_KEY_BODY            = local.ssh_key_body
      INSTALL_APPROVAL_NAME   = local.install_approval_name
      INSTALL_APPROVAL_BODY   = local.install_approval_body
      IMAGE_BODY              = local.image_body
    }
    command = "bash \"${path.module}/netcup_api.sh\" install"
  }

  depends_on = [terraform_data.netcup_firewall]
}

# Loads the persisted generated key into the caller's ssh-agent after Netcup's
# image task has completed.
resource "terraform_data" "ssh_agent_loaded" {
  triggers_replace = {
    key_id     = tls_private_key.user.id
    install_id = terraform_data.debian_install.id
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = {
      SSH_KEY = tls_private_key.user.private_key_openssh
    }
    command = <<-EOT
      set -euo pipefail
      if [ -z "$${SSH_AUTH_SOCK:-}" ]; then
        echo "SSH_AUTH_SOCK is not set. Start an ssh-agent before applying." >&2
        exit 1
      fi
      printf '%s\n' "$SSH_KEY" | ssh-add - >/dev/null
    EOT
  }

  depends_on = [terraform_data.debian_install]
}

resource "terraform_data" "ssh_ready" {
  triggers_replace = {
    server_id  = tostring(var.netcup_server_id)
    ssh_port   = random_integer.ssh_port.result
    install_id = terraform_data.debian_install.id
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = {
      HOST                      = local.server.ipv4Addresses[0].ip
      SSH_PORT                  = tostring(random_integer.ssh_port.result)
      USERNAME                  = var.username
      TWINGATE_ACCESS_RESOURCES = coalesce(var.ssh_ready_wait_for, "")
    }
    command = <<-EOT
      set -euo pipefail
      for attempt in $(seq 1 120); do
        if ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
          -o UserKnownHostsFile=/dev/null -p "$SSH_PORT" "$USERNAME@$HOST" \
          'test -f /var/lib/netcup-bootstrap-complete' 2>/dev/null; then
          exit 0
        fi
        sleep 5
      done
      echo "Timed out waiting for the Netcup bootstrap on $HOST:$SSH_PORT" >&2
      exit 1
    EOT
  }

  depends_on = [
    terraform_data.netcup_firewall,
    terraform_data.ssh_agent_loaded,
  ]
}
