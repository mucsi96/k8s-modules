# Common Ansible vars: SSH via the agent loaded by provision_hetzner_server.
# StrictHostKeyChecking=no is intentional — the host IP comes back from the
# Hetzner Cloud API over TLS seconds before the first connect, so first-connect
# host-key verification adds plumbing without practical security.
locals {
  ansible_ssh_common_args = "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

  ansible_connection_vars = {
    ansible_port            = tostring(var.ssh_port)
    ansible_user            = var.username
    ansible_ssh_common_args = local.ansible_ssh_common_args
  }
}

# Folding var.wait_for into extra_vars (rather than a side terraform_data with
# a depends_on edge) is what actually serializes against ssh_ready. A
# terraform_data sentinel updates its `input` field in-place silently, so
# `depends_on` on it is a no-op barrier — Terraform schedules the dependent
# in parallel. Putting var.wait_for inside extra_vars forces the data-flow
# tracker to wait for the value to be known, which cannot happen until
# ssh_ready has finished polling the new sshd port. The value is passed to
# ansible-playbook as --extra-vars _wait_for=...; the playbook ignores it.
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

locals {
  apiserver_oidc_issuer_url = "https://login.microsoftonline.com/${var.azure_tenant_id}/v2.0"
  apiserver_oidc_client_id  = azuread_application.apiserver.client_id
  dashboard_oidc_client_id  = module.cluster_monitor.client_id
}

resource "terraform_data" "apiserver_oidc_args" {
  triggers_replace = {
    issuer_url          = local.apiserver_oidc_issuer_url
    apiserver_client_id = local.apiserver_oidc_client_id
    dashboard_client_id = local.dashboard_oidc_client_id
  }
}

resource "ansible_playbook" "configure_microk8s_apiserver_oidc" {
  name       = var.host
  playbook   = "${path.module}/configure_microk8s_apiserver_oidc.yaml"
  replayable = false

  extra_vars = merge(local.ansible_connection_vars, {
    oidc_issuer_url     = local.apiserver_oidc_issuer_url
    apiserver_client_id = local.apiserver_oidc_client_id
    dashboard_client_id = local.dashboard_oidc_client_id
  })

  lifecycle {
    replace_triggered_by = [terraform_data.apiserver_oidc_args]
  }

  depends_on = [ansible_playbook.configure_microk8s_oidc]
}

# Captures the IDs of the playbooks that can rotate the calico service-account
# token (snap install/refresh, OIDC apiserver flag changes). When any of those
# playbooks is replaced — e.g. on first apply, on a manual `-replace`, or on
# an apiserver_oidc config change — this terraform_data is replaced too, which
# in turn causes ansible_playbook.restart_calico to be replaced via
# replace_triggered_by. Routine applies that touch nothing here leave it alone.
resource "terraform_data" "calico_restart_trigger" {
  triggers_replace = {
    install_microk8s_id         = ansible_playbook.install_microk8s.id
    configure_microk8s_oidc_id  = ansible_playbook.configure_microk8s_oidc.id
    configure_apiserver_oidc_id = ansible_playbook.configure_microk8s_apiserver_oidc.id
  }
}

# Force the Calico CNI to pick up rotated apiserver tokens before the next
# helm release tries to schedule pods. install_microk8s, configure_microk8s_oidc
# and configure_microk8s_apiserver_oidc can each rotate the calico
# service-account token, but the on-host /etc/cni/net.d/calico-kubeconfig only
# gets rewritten when the calico-node pod restarts — otherwise every new pod
# sandbox creation fails with "connection is unauthorized: Unauthorized" and
# downstream helm_releases (workload_identity_webhook, traefik, ...) hang.
resource "ansible_playbook" "restart_calico" {
  name       = var.host
  playbook   = "${path.module}/restart_calico.yaml"
  replayable = false

  extra_vars = local.ansible_connection_vars

  lifecycle {
    replace_triggered_by = [terraform_data.calico_restart_trigger]
  }

  depends_on = [
    ansible_playbook.install_microk8s,
    ansible_playbook.configure_microk8s_oidc,
    ansible_playbook.configure_microk8s_apiserver_oidc,
  ]
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
    ansible_playbook.restart_calico,
  ]
}

# Cluster-admin binding for the human running Terraform. The apiserver's
# structured-auth config (configure_microk8s_apiserver_oidc.yaml) maps tokens
# with aud = apiserver_app to the bare `oid` claim, so var.owner is the
# operator's Kubernetes username when they kubelogin. The kubernetes provider
# is configured in the root from this module's admin-cert outputs, so this
# resource applies on first bootstrap without any chicken-and-egg with
# kubelogin.
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

  depends_on = [
    ansible_playbook.configure_microk8s_oidc,
    ansible_playbook.configure_microk8s_apiserver_oidc,
    ansible_playbook.restart_calico,
  ]
}

# View-only binding for Headlamp's authenticated user. Tokens issued to the
# dashboard's oauth2-proxy (aud = cluster_monitor_app) are mapped by the
# structured-auth config to "headlamp:<oid>" — a distinct Kubernetes username
# from the bare `oid` that oidc_human_admin binds to cluster-admin. So when
# the operator clicks through Headlamp, the apiserver sees a different user
# and grants only `view` (plus whatever extras setup_k8s_dashboard's
# headlamp_view_extras ClusterRole aggregates into `view`).
resource "kubernetes_cluster_role_binding_v1" "oidc_dashboard_view" {
  metadata {
    name = "oidc-dashboard-view"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "view"
  }

  subject {
    kind      = "User"
    name      = "headlamp:${var.owner}"
    api_group = "rbac.authorization.k8s.io"
  }

  depends_on = [
    ansible_playbook.configure_microk8s_oidc,
    ansible_playbook.configure_microk8s_apiserver_oidc,
    ansible_playbook.restart_calico,
  ]
}
