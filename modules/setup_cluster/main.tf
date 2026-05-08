resource "terraform_data" "wait_for" {
  input = var.wait_for
}

# Common Ansible vars: SSH via the agent loaded by provision_hetzner_server,
# accept-new pinned to a per-apply known_hosts file so the first connect
# records the host key and every subsequent connect verifies it, without ever
# touching the operator's ~/.ssh/known_hosts.
locals {
  user_known_hosts_file   = coalesce(var.known_hosts_file, "/dev/null")
  ansible_ssh_common_args = "-o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=${local.user_known_hosts_file}"

  ansible_connection_vars = {
    ansible_port            = tostring(var.ssh_port)
    ansible_user            = var.username
    ansible_ssh_common_args = local.ansible_ssh_common_args
  }
}

resource "ansible_playbook" "system_update" {
  name       = var.host
  playbook   = "${path.module}/system_update.yaml"
  replayable = false

  extra_vars = local.ansible_connection_vars

  depends_on = [terraform_data.wait_for]
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
      type    = "ssh"
      host    = var.host
      port    = var.ssh_port
      user    = var.username
      agent   = true
      timeout = "10m"
    }
  }

  depends_on = [ansible_playbook.system_update]
}

resource "ansible_playbook" "install_microk8s" {
  name       = var.host
  playbook   = "${path.module}/install_microk8s.yaml"
  replayable = false

  extra_vars = merge(local.ansible_connection_vars, {
    azure_key_vault_name     = var.azure_key_vault_name
    azure_subscription_id    = var.azure_subscription_id
    local_python_interpreter = var.local_python_interpreter
  })

  lifecycle {
    ignore_changes = [extra_vars["local_python_interpreter"]]
  }

  depends_on = [terraform_data.wait_for_system]
}

resource "ansible_playbook" "configure_dns" {
  name       = var.host
  playbook   = "${path.module}/configure_dns.yaml"
  replayable = false

  extra_vars = local.ansible_connection_vars

  depends_on = [ansible_playbook.install_microk8s]
}

data "azurerm_storage_account" "oidc" {
  name                = var.storage_account_name
  resource_group_name = var.environment_name
}

resource "ansible_playbook" "publish_microk8s_oidc" {
  name       = var.host
  playbook   = "${path.module}/publish_microk8s_oidc.yaml"
  replayable = false

  extra_vars = merge(local.ansible_connection_vars, {
    resource_group           = var.environment_name
    storage_account_name     = var.storage_account_name
    issuer                   = data.azurerm_storage_account.oidc.primary_web_endpoint
    azwi_version             = "v1.5.1"
    local_python_interpreter = var.local_python_interpreter
  })

  lifecycle {
    ignore_changes = [extra_vars["local_python_interpreter"]]
  }

  depends_on = [ansible_playbook.configure_dns]
}

resource "ansible_playbook" "configure_microk8s_oidc" {
  name       = var.host
  playbook   = "${path.module}/configure_microk8s_oidc.yaml"
  replayable = false

  extra_vars = merge(local.ansible_connection_vars, {
    issuer = data.azurerm_storage_account.oidc.primary_web_endpoint
  })

  depends_on = [ansible_playbook.publish_microk8s_oidc]
}

resource "terraform_data" "apiserver_oidc_args" {
  count = var.apiserver_oidc == null ? 0 : 1

  triggers_replace = {
    issuer_url     = var.apiserver_oidc.issuer_url
    client_id      = var.apiserver_oidc.client_id
    username_claim = var.apiserver_oidc.username_claim
    groups_claim   = var.apiserver_oidc.groups_claim == null ? "" : var.apiserver_oidc.groups_claim
  }
}

resource "ansible_playbook" "configure_microk8s_apiserver_oidc" {
  count = var.apiserver_oidc == null ? 0 : 1

  name       = var.host
  playbook   = "${path.module}/configure_microk8s_apiserver_oidc.yaml"
  replayable = false

  extra_vars = merge(local.ansible_connection_vars, {
    oidc_issuer_url     = var.apiserver_oidc.issuer_url
    oidc_client_id      = var.apiserver_oidc.client_id
    oidc_username_claim = var.apiserver_oidc.username_claim
    oidc_groups_claim   = var.apiserver_oidc.groups_claim == null ? "" : var.apiserver_oidc.groups_claim
  })

  lifecycle {
    replace_triggered_by = [terraform_data.apiserver_oidc_args[0]]
  }

  depends_on = [ansible_playbook.configure_microk8s_oidc]
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

  depends_on = [
    ansible_playbook.configure_microk8s_oidc,
    ansible_playbook.configure_microk8s_apiserver_oidc,
  ]
}
