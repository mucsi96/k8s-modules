locals {
  ansible_ssh_common_args = "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
  ansible_connection_vars = {
    ansible_port            = tostring(var.ssh_port)
    ansible_user            = var.username
    ansible_ssh_common_args = local.ansible_ssh_common_args
  }
  apiserver_oidc_issuer_url = "https://login.microsoftonline.com/${var.azure_tenant_id}/v2.0"
  apiserver_oidc_client_id  = azuread_application.apiserver.client_id
}

data "azurerm_storage_account" "oidc" {
  name                = var.storage_account_name
  resource_group_name = var.environment_name
}

# wait_for is carried as an extra var so Ansible cannot start before the
# provision_server SSH readiness value is known.
resource "ansible_playbook" "system_update" {
  name       = var.host
  playbook   = "${path.module}/system_update.yaml"
  replayable = false

  extra_vars = merge(local.ansible_connection_vars, {
    _wait_for = coalesce(var.wait_for, "")
  })
}

resource "terraform_data" "wait_for_system" {
  triggers_replace = {
    last_run = ansible_playbook.system_update.id
  }

  provisioner "remote-exec" {
    inline = ["test -f /var/lib/netcup-bootstrap-complete"]

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

resource "ansible_playbook" "configure_dns" {
  name       = var.host
  playbook   = "${path.module}/configure_dns.yaml"
  replayable = false
  extra_vars = local.ansible_connection_vars

  depends_on = [terraform_data.wait_for_system]
}

resource "ansible_playbook" "install_k3s" {
  name       = var.host
  playbook   = "${path.module}/install_k3s.yaml"
  replayable = false

  extra_vars = merge(local.ansible_connection_vars, {
    api_host                 = var.host
    k3s_api_port             = tostring(var.k3s_api_port)
    k3s_version              = var.k3s_version
    workload_identity_issuer = data.azurerm_storage_account.oidc.primary_web_endpoint
    oidc_issuer_url          = local.apiserver_oidc_issuer_url
    apiserver_client_id      = local.apiserver_oidc_client_id
    azure_key_vault_name     = var.azure_key_vault_name
    azure_subscription_id    = var.azure_subscription_id
    local_python_interpreter = var.local_python_interpreter
  })

  lifecycle {
    ignore_changes = [extra_vars["local_python_interpreter"]]
  }

  depends_on = [ansible_playbook.configure_dns]
}

resource "ansible_playbook" "publish_k3s_oidc" {
  name       = var.host
  playbook   = "${path.module}/publish_k3s_oidc.yaml"
  replayable = false

  extra_vars = merge(local.ansible_connection_vars, {
    resource_group           = var.environment_name
    storage_account_name     = var.storage_account_name
    issuer                   = data.azurerm_storage_account.oidc.primary_web_endpoint
    local_python_interpreter = var.local_python_interpreter
  })

  lifecycle {
    ignore_changes = [extra_vars["local_python_interpreter"]]
  }

  depends_on = [ansible_playbook.install_k3s]
}

resource "helm_release" "workload_identity_webhook" {
  name             = "workload-identity-webhook"
  repository       = "https://azure.github.io/azure-workload-identity/charts"
  chart            = "workload-identity-webhook"
  namespace        = "azure-workload-identity-system"
  create_namespace = true

  values = [yamlencode({
    azureTenantID = var.azure_tenant_id
    replicaCount  = 1
    resources = {
      requests = {
        cpu    = "10m"
        memory = "32Mi"
      }
      limits = {
        memory = "64Mi"
      }
    }
  })]

  depends_on = [
    ansible_playbook.install_k3s,
    ansible_playbook.publish_k3s_oidc,
  ]
}

resource "kubernetes_cluster_role_binding_v1" "oidc_human_admin" {
  metadata {
    name = "oidc-human-admin"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    kind      = "User"
    name      = var.owner
    api_group = "rbac.authorization.k8s.io"
  }

  depends_on = [ansible_playbook.install_k3s]
}
