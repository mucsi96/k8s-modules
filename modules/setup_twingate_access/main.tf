# Twingate access layer: who and what can reach the cluster through Twingate.
# Needs the server's address/port, so it is created after provision_hetzner_server
# (via field references — never a module-level depends_on, which would form a
# cycle with the ssh_ready_wait_for edge back into that module).

# Reference Twingate's built-in "Everyone" system group (every user in the
# network) and grant it operator access to SSH + the K8s API. Using the
# precreated group avoids managing membership in Terraform; in this single-
# operator tenant "everyone" is the operator. types is pinned to SYSTEM so we
# match the built-in group, never a manually-created group of the same name.
data "twingate_groups" "everyone" {
  name  = "Everyone"
  types = ["SYSTEM"]
}

# Service account for GitHub Actions (app deploy workflows reach the K8s API
# through this). Token is unchanged in shape from the previous module, so the
# TWINGATE_SERVICE_KEY GitHub/Key Vault secret flow is identical.
resource "twingate_service_account" "github_actions" {
  name = "${var.environment_name}-github-actions"
}

resource "twingate_service_account_key" "github_actions" {
  service_account_id = twingate_service_account.github_actions.id
  name               = "${var.environment_name}-github-actions-key"
}

# K8s API: operators (humans, via the Everyone group) and GitHub Actions (via
# the service account).
resource "twingate_resource" "k8s_api" {
  name              = "${var.environment_name} Kubernetes API"
  remote_network_id = var.remote_network_id
  address           = var.k8s_host

  protocols = {
    allow_icmp = false
    tcp = {
      policy = "RESTRICTED"
      ports  = ["16443"]
    }
    udp = {
      policy = "DENY_ALL"
    }
  }

  access_group {
    group_id = data.twingate_groups.everyone.groups[0].id
  }

  access_service {
    service_account_id = twingate_service_account.github_actions.id
  }
}

# SSH: operators only (Everyone group) — no service account. ICMP allowed so
# operators can ping the host for diagnostics (the public ICMP rule is removed).
resource "twingate_resource" "ssh" {
  name              = "${var.environment_name} SSH"
  remote_network_id = var.remote_network_id
  address           = var.ssh_address

  protocols = {
    allow_icmp = true
    tcp = {
      policy = "RESTRICTED"
      ports  = [tostring(var.ssh_port)]
    }
    udp = {
      policy = "DENY_ALL"
    }
  }

  access_group {
    group_id = data.twingate_groups.everyone.groups[0].id
  }
}
