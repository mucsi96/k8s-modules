# Kubernetes Terraform Modules

Reusable Terraform modules for provisioning a private MicroK8s cluster on
Hetzner and the Azure, Cloudflare, Twingate, GitHub, and Kubernetes resources
around it.

This repository is a module library. It deliberately has no root Terraform
configuration, backend, state, environment values, or apply/destroy scripts.
Those belong in a separate consumer repository. Do not run `terraform apply` or
`terraform destroy` from this checkout.

## Using A Module

Pin every module used by one environment to the same release tag:

```hcl
module "setup_cluster" {
  source = "git::https://github.com/mucsi96/k8s-modules.git//modules/setup_cluster?ref=<release-tag>"

  # See modules/setup_cluster/variables.tf for the required inputs.
}
```

Do not use a moving branch such as `main` for deployed infrastructure. Module
inputs and outputs are documented in each module's `variables.tf` and
`outputs.tf` files. Provider versions and the dependency lock file belong to
the consumer repository.

## Module Catalog

### Host And Cluster

| Module | Purpose |
| --- | --- |
| `setup_twingate_connector` | Creates the Twingate remote network, host connector, and connector tokens that are embedded in server cloud-init. |
| `provision_hetzner_server` | Creates the SSH key and port, Hetzner server, Cloudflare-only HTTPS firewall, host Twingate connector configuration, and SSH readiness barrier. |
| `setup_twingate_access` | Creates Twingate resources for SSH and the Kubernetes API plus a service account/key for CI access. |
| `setup_cluster` | Installs and configures MicroK8s through Ansible, publishes OIDC metadata, configures Entra authentication and Azure workload identity, and outputs Kubernetes credentials. |

### Cluster Services

| Module | Purpose |
| --- | --- |
| `setup_ingress_controller` | Installs Traefik, Gateway API resources, Cloudflare DNS/security configuration, and origin TLS. |
| `setup_metrics_server` | Installs metrics-server with MicroK8s-compatible kubelet settings. |
| `setup_oauth2_proxy` | Reusable Entra OIDC proxy backed by Redis sessions. |
| `create_app_namespace` | Creates an application namespace, service account, RBAC, token secret, and deployment kubeconfig. |

### Data And Observability

| Module | Purpose |
| --- | --- |
| `setup_monitoring_crds` | Installs monitoring CRDs before charts that create `ServiceMonitor`, `PodMonitor`, or `PrometheusRule` objects. |
| `create_postgres_database` | Installs PostgreSQL with generated credentials, a retained host-path PV, and a `ServiceMonitor`. |
| `setup_redis` | Installs shared Redis with generated credentials and a retained host-path PV. |
| `setup_victoria_metrics` | Installs `victoria-metrics-k8s-stack`, including VMSingle, vmagent, VMAlert, Grafana, exporters, and VLSingle. |
| `setup_victoria_logs` | Installs Alloy pod-log collection and a Faro receiver that write to the VLSingle owned by `setup_victoria_metrics`. |

### Identity And Application Foundations

| Module | Purpose |
| --- | --- |
| `register_api` | Registers an Entra API, app roles/scopes, workload identity, service principal, and client credential. |
| `register_spa` | Registers an Entra SPA and pre-authorizes access to an API. |
| `register_webapp` | Registers a confidential Entra web application for oauth2-proxy. |
| `register_github_oidc` | Registers GitHub Actions federation and grants Key Vault access. |
| `setup_app_base` | Composes namespace/RBAC, app Key Vault, deployment identity, GitHub Actions secrets, and Docker Hub access. |
| `setup_bank_email_worker` | Creates a Cloudflare Email Worker and routing rule for authenticated bank-notification delivery. |

### Opinionated Applications

`setup_hello_app`, `setup_learn_language_app`, `setup_training_log_app`,
`setup_party_app`, `setup_library_app`, `setup_expense_tracker_app`,
`setup_cooking_app`, and `setup_backup_app` configure infrastructure needed by
their application repositories: Entra registrations, namespace access, Key
Vault secrets, GitHub deployment credentials, and where applicable database or
backup storage. They do not install the application workloads themselves.

## Consumer Composition

The consumer owns all provider configuration. Configure the Kubernetes-facing
providers from `setup_cluster` outputs so their resources are graph-dependent
on the cluster:

```hcl
provider "kubernetes" {
  host                   = module.setup_cluster.k8s_host
  client_certificate     = module.setup_cluster.k8s_client_certificate
  client_key             = module.setup_cluster.k8s_client_key
  cluster_ca_certificate = module.setup_cluster.k8s_cluster_ca_certificate
}

provider "helm" {
  kubernetes = {
    host                   = module.setup_cluster.k8s_host
    client_certificate     = module.setup_cluster.k8s_client_certificate
    client_key             = module.setup_cluster.k8s_client_key
    cluster_ca_certificate = module.setup_cluster.k8s_cluster_ca_certificate
  }
}

provider "kubectl" {
  host                   = module.setup_cluster.k8s_host
  client_certificate     = module.setup_cluster.k8s_client_certificate
  client_key             = module.setup_cluster.k8s_client_key
  cluster_ca_certificate = module.setup_cluster.k8s_cluster_ca_certificate
  load_config_file       = false
}
```

The full creation dependency chain is:

```text
Twingate connector
  -> Hetzner server
  -> Twingate SSH and Kubernetes API resources
  -> SSH readiness
  -> MicroK8s cluster
  -> Traefik and Gateway API
  -> Monitoring CRDs
  -> PostgreSQL and VictoriaMetrics
  -> VictoriaLogs collectors and dependent applications
```

Redis is a parallel prerequisite for oauth2-proxy users. Metrics-server follows
Traefik in the existing topology.

### Twingate Lifecycle Barrier

The host/access relationship intentionally forms a resource-level back-edge.
Connector tokens flow into the server, the server address flows into the access
module, and both access resource IDs flow into only the server module's
`ssh_ready` resource:

```hcl
module "setup_twingate_connector" {
  source = "git::https://github.com/mucsi96/k8s-modules.git//modules/setup_twingate_connector?ref=<release-tag>"

  environment_name = var.environment_name
}

module "provision_hetzner_server" {
  source = "git::https://github.com/mucsi96/k8s-modules.git//modules/provision_hetzner_server?ref=<release-tag>"

  # Other required inputs are omitted here.
  twingate_access_token  = module.setup_twingate_connector.access_token
  twingate_refresh_token = module.setup_twingate_connector.refresh_token
  ssh_ready_wait_for = join(",", [
    module.setup_twingate_access.ssh_resource_id,
    module.setup_twingate_access.k8s_resource_id,
  ])
}

module "setup_twingate_access" {
  source = "git::https://github.com/mucsi96/k8s-modules.git//modules/setup_twingate_access?ref=<release-tag>"

  environment_name  = var.environment_name
  remote_network_id = module.setup_twingate_connector.remote_network_id
  k8s_host          = module.provision_hetzner_server.ipv4_address
  ssh_address       = module.provision_hetzner_server.ipv4_address
  ssh_port          = module.provision_hetzner_server.ssh_port
}

module "setup_cluster" {
  source = "git::https://github.com/mucsi96/k8s-modules.git//modules/setup_cluster?ref=<release-tag>"

  # Other required inputs are omitted here.
  host     = module.provision_hetzner_server.ipv4_address
  ssh_port = module.provision_hetzner_server.ssh_port
  username = module.provision_hetzner_server.username
  wait_for = module.provision_hetzner_server.ssh_ready
}
```

Do not replace this with module-level `depends_on` between
`provision_hetzner_server` and `setup_twingate_access`; that creates a cycle.
The `ssh_ready_wait_for` value is used only by `terraform_data.ssh_ready`, which
allows Terraform to build the intended resource graph. On destroy, the graph is
reversed and both Twingate access resources remain until Kubernetes and Helm no
longer need the API.

An active `SSH_AUTH_SOCK` and a connected Twingate client are required while
creating or updating the server and cluster. The consumer's automation should
start `ssh-agent`, load the generated/recovered key, and verify private access.

### CRD And Service Ordering

Preserve these relationships in the consumer:

```hcl
module "setup_ingress_controller" {
  # Inputs omitted.
  depends_on = [module.setup_cluster]
}

module "setup_monitoring_crds" {
  # Inputs omitted.
  wait_for = module.setup_ingress_controller.traefik_ready
}

module "create_postgres_database" {
  # Inputs omitted. Its chart creates a ServiceMonitor.
  wait_for = module.setup_monitoring_crds.crds_ready
}

module "setup_victoria_metrics" {
  # Inputs include PostgreSQL and Redis outputs.
  wait_for   = module.setup_ingress_controller.traefik_ready
  depends_on = [module.setup_monitoring_crds]
}

module "setup_victoria_logs" {
  victoria_logs_url = module.setup_victoria_metrics.victoria_logs_url
  wait_for          = module.setup_victoria_metrics.victoria_metrics_k8s_stack_ready
  # Other inputs omitted.
}
```

Traefik owns the Gateway API CRDs used by module HTTPRoutes. Monitoring CRDs
must exist before PostgreSQL or VictoriaMetrics charts create objects, and must
outlive those objects during destroy.

## Migration Guide

This release is a breaking, dashboard-focused cleanup. It removes web tools
that are no longer part of the supported cluster topology, removes their public
interfaces, and renames the monitoring modules around VictoriaMetrics. Grafana
remains installed and publicly available through oauth2-proxy.

This guide assumes a direct upgrade. It does not preserve Terraform resource
addresses for renamed module blocks and does not require migration or `moved`
blocks.

### Change Summary

| Previous interface | New interface |
| --- | --- |
| `setup_prometheus_operator` module path | `setup_victoria_metrics` |
| `setup_prometheus_operator_crds` module path | `setup_monitoring_crds` |
| `setup_cloudbeaver` | Removed |
| `setup_k8s_dashboard` | Removed |
| Traefik dashboard, Entra application, oauth2-proxy, and HTTPRoute | Removed from `setup_ingress_controller` |
| Public Prometheus/VMUI oauth2-proxy and HTTPRoute | Removed from `setup_victoria_metrics` |
| Headlamp Entra application, API-server audience, and read-only RBAC | Removed from `setup_cluster` |
| Grafana, its PostgreSQL state, oauth2-proxy, and HTTPRoute | Retained in `setup_victoria_metrics` |

Prometheus-compatible CRDs such as `ServiceMonitor`, `PodMonitor`, and
`PrometheusRule` are still required by VictoriaMetrics and application charts.
The `setup_monitoring_crds` module therefore still installs the upstream
`prometheus-operator-crds` Helm chart, and its
`prometheus_operator_crds_chart_version` input keeps that upstream name.

### Update Module Blocks

Delete the complete consumer module blocks for these removed modules:

```hcl
module "setup_cloudbeaver" {
  # Removed.
}

module "setup_k8s_dashboard" {
  # Removed.
}
```

Replace the old monitoring module paths and use the new module names:

```hcl
module "setup_monitoring_crds" {
  source = "git::https://github.com/mucsi96/k8s-modules.git//modules/setup_monitoring_crds?ref=<new-release>"

  prometheus_operator_crds_chart_version = var.prometheus_operator_crds_chart_version
  wait_for                               = module.setup_ingress_controller.traefik_ready
}

module "setup_victoria_metrics" {
  source = "git::https://github.com/mucsi96/k8s-modules.git//modules/setup_victoria_metrics?ref=<new-release>"

  victoria_metrics_k8s_stack_chart_version = var.victoria_metrics_k8s_stack_chart_version
  grafana_hostname                         = var.grafana_hostname
  grafana_client_id                        = module.register_grafana.client_id
  grafana_client_secret                    = module.register_grafana.client_secret
  tenant_id                                = var.tenant_id
  valid_email                              = var.valid_email
  oauth2_proxy_chart_version               = var.oauth2_proxy_chart_version
  oauth2_proxy_image_version               = var.oauth2_proxy_image_version
  session_redis                            = module.setup_redis
  wait_for                                 = module.setup_ingress_controller.traefik_ready
  database = {
    host           = module.create_postgres_database.host
    port           = module.create_postgres_database.port
    name           = module.create_postgres_database.name
    admin_username = module.create_postgres_database.username
    admin_password = module.create_postgres_database.password
  }

  depends_on = [module.setup_monitoring_crds]
}
```

Update all references to the old module names. In particular:

```hcl
module "setup_victoria_logs" {
  # Other inputs omitted.
  victoria_logs_url = module.setup_victoria_metrics.victoria_logs_url
  wait_for          = module.setup_victoria_metrics.victoria_metrics_k8s_stack_ready
}

module "create_postgres_database" {
  # Other inputs omitted.
  wait_for = module.setup_monitoring_crds.crds_ready
}
```

### Remove Obsolete Inputs

Remove the following arguments from consumer module blocks and any variables or
locals that only supplied them:

| Module | Removed arguments |
| --- | --- |
| `setup_cluster` | `cluster_monitor_redirect_uris` |
| `setup_ingress_controller` | `environment_name`, `subscription_id`, `tenant_id`, `owner`, `oauth2_proxy_chart_version`, `oauth2_proxy_image_version`, `valid_email`, `session_redis` |
| `setup_victoria_metrics` | `prometheus_hostname`, `prometheus_client_id`, `prometheus_client_secret` |

The `owner` input remains required by `setup_cluster` for the Kubernetes
API-server Entra application and the operator's cluster-admin binding. Grafana
also continues to require its hostname, Entra client credentials, tenant,
allowed email, oauth2-proxy versions, Redis session backend, and PostgreSQL
database inputs.

### Remove Obsolete Outputs And Dependencies

The following outputs no longer exist:

| Removed module | Removed outputs |
| --- | --- |
| `setup_cluster` | `cluster_monitor_client_id`, `cluster_monitor_client_secret` |
| `setup_cloudbeaver` | `k8s_namespace`, `hostname`, `admin_password` |
| `setup_k8s_dashboard` | `k8s_namespace`, `hostname` |

Remove references to those outputs from locals, secrets, DNS configuration,
application registrations, and dependency expressions. Remove any consumer-owned
Entra web applications used only by CloudBeaver, Headlamp, or the public
Prometheus/VMUI route. Keep the Grafana Entra application.

Redis and PostgreSQL are still used by Grafana. Do not remove shared Redis or
PostgreSQL modules merely because the other dashboards were removed.

`setup_ingress_controller` no longer requires the `azurerm`, `azuread`, or
`random` providers. Remove provider aliases passed exclusively to that module,
but retain any root provider configurations used by other modules. The ingress
module still requires `kubernetes`, `kubectl`, `helm`, `tls`, and `cloudflare`.

### Apply The Upgrade

Make the configuration changes together, pin every module to the new release,
and then run the normal consumer workflow:

```bash
terraform fmt -recursive
terraform init -upgrade
terraform validate
terraform plan -out=migration.tfplan
terraform show migration.tfplan
terraform apply migration.tfplan
```

The plan should remove the retired dashboard resources and may recreate
resources under the renamed module blocks. Review the complete plan rather than
targeting individual modules.

Expected removals include:

- The `cloudbeaver` namespace, workload, service, secrets, oauth2-proxy, route,
  and persistent-volume objects.
- The `k8s-dashboard` namespace, Headlamp chart, extra read-only RBAC,
  oauth2-proxy, and route.
- The cluster-monitor Entra application and secret, Headlamp API-server
  audience, and `oidc-dashboard-view` role binding.
- The Traefik dashboard Entra application, oauth2-proxy, and HTTPRoute.
- The public Prometheus/VMUI oauth2-proxy and HTTPRoute.

Expected retained services include:

- Traefik ingress and Gateway API resources.
- VMSingle, vmagent, VMAlert, exporters, and monitoring CRDs.
- Grafana, its database schema, oauth2-proxy, and HTTPRoute.
- VLSingle and the VictoriaLogs collection pipeline.

The `setup_cluster` change rewrites the MicroK8s API-server authentication
configuration for the single kubelogin audience and can restart MicroK8s and
Calico during apply. Keep SSH, Twingate, and Kubernetes access available for the
entire operation.

CloudBeaver used a retained host-path volume. Removing its Kubernetes resources
does not delete `/data/cloudbeaver` from the server. Remove that directory
separately only after confirming its contents are no longer needed.

### Verify The Upgrade

Verify terminal access and the remaining monitoring stack after apply:

```bash
kubectl get nodes
kubectl get pods --all-namespaces
kubectl get httproutes --all-namespaces
kubectl auth can-i '*' '*' --all-namespaces
helm list --all-namespaces
```

Confirm that the `cloudbeaver` and `k8s-dashboard` namespaces are absent, no
Traefik or Prometheus/VMUI dashboard routes remain, and the Grafana route is
still present. Sign in to Grafana and verify that metrics and logs remain
queryable before removing any old consumer variables, secrets, or Entra
registrations outside Terraform.

## Safe Destruction

Use a full destroy plan from the consumer repository:

```bash
terraform plan -destroy -out=destroy.tfplan
terraform show destroy.tfplan
terraform apply destroy.tfplan
```

Do not routinely target the Hetzner server, cluster module, firewall, Twingate
resources, or individual prerequisites. Targeted destroy includes graph
dependents and can still remove independent access resources in parallel if the
consumer omitted the lifecycle barrier above.

Terraform persists each successful deletion immediately. A failed destroy is
normally a valid partial state, not a corrupt state. Fix the failing resource
and run a new full destroy plan.

Never remove `kubernetes_*`, `helm_release`, or `kubectl_manifest` addresses from
state merely because one Helm hook failed. State removal is appropriate only
after independently confirming that the cluster is permanently gone and the
in-cluster objects therefore no longer exist. Back up remote state before any
recovery operation and review every address being removed.

The VictoriaMetrics operator subchart uses the short fullname `vm-operator` in
this library. This keeps its pre-delete cleanup Job labels under Kubernetes'
63-byte limit. Consumers overriding that value must keep the generated
`<fullname>-cleanup-hook` label at or below 63 bytes.

An existing release installed without this override still contains the broken
pre-delete hook. Apply the updated `setup_victoria_metrics` module once while
the API is reachable so Helm records a corrected release revision before
destroying it. For immediate teardown only, the fallback is:

```bash
helm uninstall victoria-metrics-k8s-stack --namespace monitoring --no-hooks
```

Confirm the release is gone, then remove only its `helm_release` address from
Terraform state. Skipping the cleanup hook is acceptable only when the whole
cluster is being removed.

## Development

Format and validate modules independently; there is no root module to validate:

```bash
terraform fmt -check -diff -recursive modules

for dir in modules/*/; do
  terraform -chdir="$dir" init -backend=false
  terraform -chdir="$dir" validate
done
```

`setup_cluster` executes Ansible playbooks. Install the collections from
`requirements.yml` and Python packages from `requirements.txt` in the consumer
or CI environment before applying it.
