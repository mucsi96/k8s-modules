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
  filename             = "${path.module}/.generated/${var.server_name}-id_ed25519"
}

resource "hcloud_ssh_key" "user" {
  name       = "${var.server_name}-${var.username}"
  public_key = tls_private_key.user.public_key_openssh
}

resource "hcloud_server" "cluster" {
  name        = var.server_name
  server_type = var.server_type
  image       = var.image
  location    = var.location
  ssh_keys    = [hcloud_ssh_key.user.id]

  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }

  labels = {
    role        = "k8s"
    environment = var.environment_name
  }
}

locals {
  host = hcloud_server.cluster.ipv4_address
}

resource "terraform_data" "wait_for_ssh" {
  triggers_replace = {
    server_id = hcloud_server.cluster.id
  }

  provisioner "remote-exec" {
    inline = ["cloud-init status --wait || true"]

    connection {
      type        = "ssh"
      host        = local.host
      port        = 22
      user        = "root"
      private_key = tls_private_key.user.private_key_openssh
      timeout     = "10m"
      agent       = false
    }
  }
}

resource "terraform_data" "known_hosts_entry" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-lc"]
    command     = <<-EOT
      ssh-keyscan -H -p 22 ${local.host} >> ~/.ssh/known_hosts
      ssh-keyscan -H -p ${random_integer.ssh_port.result} ${local.host} >> ~/.ssh/known_hosts || true
    EOT
  }

  triggers_replace = {
    server_id = hcloud_server.cluster.id
  }

  depends_on = [terraform_data.wait_for_ssh]
}

resource "ansible_playbook" "bootstrap_server" {
  name       = local.host
  playbook   = "${path.module}/bootstrap_server.yaml"
  replayable = false

  extra_vars = {
    ansible_port                 = "22"
    ansible_user                 = "root"
    ansible_ssh_private_key_file = local_sensitive_file.user_private_key.filename

    username          = var.username
    public_key        = tls_private_key.user.public_key_openssh
    password          = random_password.user_password.result
    new_root_password = random_password.root_password.result
    ssh_port          = tostring(random_integer.ssh_port.result)
  }

  depends_on = [terraform_data.known_hosts_entry]
}

resource "ansible_playbook" "system_update" {
  name       = local.host
  playbook   = "${path.module}/../setup_cluster/system_update.yaml"
  replayable = false

  extra_vars = {
    ansible_port                 = tostring(random_integer.ssh_port.result)
    ansible_user                 = var.username
    ansible_become_password      = random_password.user_password.result
    ansible_ssh_private_key_file = local_sensitive_file.user_private_key.filename
  }

  depends_on = [ansible_playbook.bootstrap_server]
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
      host        = local.host
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
  name       = local.host
  playbook   = "${path.module}/../setup_cluster/install_microk8s.yaml"
  replayable = false

  extra_vars = {
    ansible_port                 = tostring(random_integer.ssh_port.result)
    ansible_user                 = var.username
    ansible_become_password      = random_password.user_password.result
    ansible_ssh_private_key_file = local_sensitive_file.user_private_key.filename
    azure_key_vault_name         = var.azure_key_vault_name
    azure_subscription_id        = var.azure_subscription_id
  }

  depends_on = [terraform_data.wait_for_system]
}

data "azurerm_storage_account" "oidc" {
  name                = var.storage_account_name
  resource_group_name = var.environment_name
}

resource "ansible_playbook" "publish_microk8s_oidc" {
  name       = local.host
  playbook   = "${path.module}/../setup_cluster/publish_microk8s_oidc.yaml"
  replayable = false

  extra_vars = {
    ansible_port                 = tostring(random_integer.ssh_port.result)
    ansible_user                 = var.username
    ansible_become_password      = random_password.user_password.result
    ansible_ssh_private_key_file = local_sensitive_file.user_private_key.filename
    resource_group               = var.environment_name
    storage_account_name         = var.storage_account_name
    issuer                       = data.azurerm_storage_account.oidc.primary_web_endpoint
    azwi_version                 = "v1.5.1"
  }

  depends_on = [ansible_playbook.install_microk8s]
}

resource "ansible_playbook" "configure_microk8s_oidc" {
  name       = local.host
  playbook   = "${path.module}/../setup_cluster/configure_microk8s_oidc.yaml"
  replayable = false

  extra_vars = {
    ansible_port                 = tostring(random_integer.ssh_port.result)
    ansible_user                 = var.username
    ansible_become_password      = random_password.user_password.result
    ansible_ssh_private_key_file = local_sensitive_file.user_private_key.filename
    issuer                       = data.azurerm_storage_account.oidc.primary_web_endpoint
  }

  depends_on = [ansible_playbook.publish_microk8s_oidc]
}

resource "helm_release" "workload_identity_webhook" {
  name             = "workload-identity-webhook"
  repository       = "https://azure.github.io/azure-workload-identity/charts"
  chart            = "workload-identity-webhook"
  namespace        = "azure-workload-identity-system"
  create_namespace = true

  values = [yamlencode({
    azureTenantID = var.azure_tenant_id
  })]

  depends_on = [ansible_playbook.configure_microk8s_oidc]
}
