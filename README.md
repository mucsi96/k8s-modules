# Kubernetes Terraform Modules

Reusable Terraform modules for a private, single-node Kubernetes platform on a
Netcup RS 1000 G12 running Debian 13 (Trixie), k3s, and k3s-packaged Traefik.

This repository is a module library. It deliberately has no root Terraform
configuration, backend, state, environment values, or apply/destroy scripts.
Those belong in a consumer repository. Pin every module used by one environment
to the same release tag rather than a moving branch.

## Module Catalog

| Module | Purpose |
| --- | --- |
| `setup_twingate_connector` | Creates the Twingate remote network, host connector, and bootstrap tokens. |
| `provision_server` | Discovers an existing Netcup RS 1000 G12 through the SCP API, installs Debian 13, configures its firewall and Twingate connector, and waits for SSH. |
| `setup_twingate_access` | Creates private Twingate resources for SSH and the k3s API. |
| `setup_cluster` | Configures Debian, installs pinned k3s, publishes OIDC metadata, configures Entra authentication and workload identity, and exports credentials. |
| `setup_ingress_controller` | Configures k3s-packaged Traefik, Gateway API, Cloudflare DNS/security, and origin TLS. |
| `setup_monitoring_crds` | Installs monitoring CRDs before charts that create monitoring resources. |
| `create_postgres_database` | Installs PostgreSQL with a retained host-path volume and `ServiceMonitor`. |
| `setup_redis` | Installs shared Redis with a retained host-path volume. |
| `setup_victoria_metrics` | Installs VictoriaMetrics, Grafana, exporters, and Grafana ingress. |
| `setup_victoria_logs` | Installs Alloy pod-log/Faro collection and Faro ingress. |

The registration, application-base, and opinionated application modules create
their Entra, Cloudflare, Key Vault, namespace, persistence, and deployment
resources. They do not install application workloads.

## Netcup Prerequisites

Netcup's SCP REST API manages existing contracts but cannot order a server.
Order the RS 1000 G12 first, then obtain the following values from the SCP API:

- `netcup_server_id` from `GET /api/v1/servers`.
- `netcup_user_id` from the authenticated SCP account.
- A Debian 13 `netcup_image_flavour_id` from
  `GET /api/v1/servers/{serverId}/imageflavours`.
- `netcup_disk_name` from `GET /api/v1/servers/{serverId}/disks`.
- A long-lived OpenID Connect refresh token stored in a local file.

The API base URL defaults to `https://www.servercontrolpanel.de/scp-core`.
Authentication uses Netcup's OAuth2 device-code flow, not the CCP API key,
webservice password, or customer number. Request and authorize a device code:

```bash
umask 077
curl -sS -X POST \
  'https://www.servercontrolpanel.de/realms/scp/protocol/openid-connect/auth/device' \
  -d 'client_id=scp' \
  -d 'scope=offline_access openid' | tee device-response.json | jq
```

Open the returned `verification_uri_complete`, sign in to SCP, and approve the
request. Exchange the authorized device code:

```bash
curl -sS -X POST \
  'https://www.servercontrolpanel.de/realms/scp/protocol/openid-connect/token' \
  -d 'grant_type=urn:ietf:params:oauth:grant-type:device_code' \
  -d 'client_id=scp' \
  --data-urlencode "device_code=$(jq -r .device_code device-response.json)" \
  | tee token-response.json | jq

REFRESH_TOKEN=$(jq -r .refresh_token token-response.json)
# Persist REFRESH_TOKEN in the caller's secret store, such as Azure Key Vault.
rm device-response.json token-response.json
```

Pass the current secret-store value through the sensitive
`netcup_refresh_token` input. The module exchanges it for short-lived access
tokens and uses any rotated refresh token for the remainder of the current run.
Refresh-token changes are authentication data only and do not replace the
firewall or server installation resources.

The Terraform runner needs `curl`, `jq`, `ssh-agent`, and a connected
Twingate client. Netcup's current authentication instructions are available in
SCP under **API > REST API Docs > Authentication**.

The HashiCorp HTTP provider has data sources but no managed resources. The
server module uses it for authenticated discovery and validation. Apply-only
`terraform_data` provisioners call the same REST API for SSH-key creation,
image installation, task polling, firewall policy updates, and interface
assignment. Destructive POSTs therefore never run during refresh or plan.

`reinstall_generation` is mandatory. Its first value approves erasing the
selected disk; changing it intentionally reinstalls and erases that disk again.
Protect Terraform state because it contains bootstrap secrets, OAuth tokens,
and HTTP request metadata.

## Consumer Composition

Configure Kubernetes-facing providers from `setup_cluster` outputs:

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

The host and access modules deliberately form a resource-level lifecycle
back-edge:

```hcl
module "setup_twingate_connector" {
  source = "git::https://github.com/mucsi96/k8s-modules.git//modules/setup_twingate_connector?ref=<release-tag>"

  environment_name = var.environment_name
}

module "provision_server" {
  source = "git::https://github.com/mucsi96/k8s-modules.git//modules/provision_server?ref=<release-tag>"

  server_name             = var.server_name
  netcup_server_id        = var.netcup_server_id
  netcup_user_id          = var.netcup_user_id
  netcup_refresh_token    = var.netcup_refresh_token
  netcup_image_flavour_id = var.netcup_image_flavour_id
  netcup_disk_name        = var.netcup_disk_name
  reinstall_generation   = var.reinstall_generation
  https_source_ips        = concat(var.cloudflare_ipv4_cidrs, var.cloudflare_ipv6_cidrs)
  twingate_network        = var.twingate_network
  twingate_access_token   = module.setup_twingate_connector.access_token
  twingate_refresh_token  = module.setup_twingate_connector.refresh_token
  ssh_ready_wait_for = join(",", [
    module.setup_twingate_access.ssh_resource_id,
    module.setup_twingate_access.k8s_resource_id,
  ])
}

module "setup_twingate_access" {
  source = "git::https://github.com/mucsi96/k8s-modules.git//modules/setup_twingate_access?ref=<release-tag>"

  environment_name  = var.environment_name
  remote_network_id = module.setup_twingate_connector.remote_network_id
  k8s_host          = module.provision_server.ipv4_address
  k8s_port          = 6443
  ssh_address       = module.provision_server.ipv4_address
  ssh_port          = module.provision_server.ssh_port
}

module "setup_cluster" {
  source = "git::https://github.com/mucsi96/k8s-modules.git//modules/setup_cluster?ref=<release-tag>"

  host     = module.provision_server.ipv4_address
  ssh_port = module.provision_server.ssh_port
  username = module.provision_server.username
  wait_for = module.provision_server.ssh_ready

  # Azure inputs omitted.
}
```

Do not replace this with module-level `depends_on` between `provision_server`
and `setup_twingate_access`; that creates a cycle. On destroy, the graph is
reversed so private access remains available while Kubernetes resources are
removed.

Pass the shared Gateway contract to modules that create HTTPRoutes:

```hcl
module "setup_ingress_controller" {
  # Other inputs omitted.
  k8s_config = module.setup_cluster.k8s_config
}

module "setup_victoria_metrics" {
  # Other inputs omitted.
  gateway_parent_ref = module.setup_ingress_controller.gateway_parent_ref
  wait_for            = module.setup_ingress_controller.ingress_controller_ready
}

module "setup_victoria_logs" {
  # Other inputs omitted.
  gateway_parent_ref = module.setup_ingress_controller.gateway_parent_ref
  wait_for            = module.setup_victoria_metrics.victoria_metrics_k8s_stack_ready
}
```

The full creation chain is:

```text
Twingate connector
  -> Netcup firewall and Debian installation
  -> Twingate SSH and Kubernetes API resources
  -> authenticated SSH readiness
  -> k3s cluster and OIDC publication
  -> bundled Traefik configuration and programmed Gateway
  -> monitoring CRDs
  -> PostgreSQL, Redis, VictoriaMetrics, VictoriaLogs, and applications
```

## Platform Details

k3s is pinned by `setup_cluster.k3s_version`; the default is
`v1.36.4+k3s1`. That release also controls bundled Traefik and Metrics Server.
ServiceLB is disabled because Traefik binds host port 443 directly.

The Traefik controller and its `HelmChartConfig` run in `kube-system`. The
shared Gateway and Cloudflare Origin CA secret remain in `traefik`. The ingress
readiness token is the UID of a Gateway that has reported both `Accepted=True`
and `Programmed=True`.

The Netcup firewall accepts TCP 443 from Cloudflare IPv4 and IPv6 ranges.
Netcup's mandatory copied policies are preserved for DNS and installation
traffic. Netcup changes its implicit ingress action to DROP when ingress rules
are present. With no egress rule, implicit egress remains ACCEPT. Port 80, SSH,
and the k3s API are not publicly accepted; SSH and port 6443 use Twingate. This
restrictive upstream policy makes Twingate use its TCP relay path rather than
direct UDP peer-to-peer connectivity.

## Persistence and Reinstallation

Use database-consistent backups and verify each static host-path PV/PVC binds
to its intended path before permitting writes after a restore.
Changing `reinstall_generation` after resources exist requires destroying the
in-cluster resources first and then rebuilding them after the disk erase; a
single apply cannot refresh resources before and after replacing their cluster.

Consumer automation must load `provision_server.ssh_private_key` into its
ssh-agent on every run. The module loads it during initial creation, but a new
runner process cannot inherit that earlier agent state.

## Verification

```bash
kubectl get nodes
kubectl get pods --all-namespaces
kubectl get gatewayclass
kubectl get gateway,httproute --all-namespaces
kubectl top node
helm list --all-namespaces
```

Confirm Gateway and HTTPRoute conditions include `Accepted=True`,
`Programmed=True` where applicable, and `ResolvedRefs=True`. Confirm exactly one
Traefik and one Metrics Server deployment, no ServiceLB pods, human kubelogin,
workload identity, Grafana metrics/logs, Faro ingestion, and application data.
From outside Twingate verify that ports 22, the randomized SSH port, 6443, and
80 are closed and that direct port 443 connections outside Cloudflare are
blocked for both IPv4 and IPv6.

## Safe Destruction

Use a full destroy plan from the consumer. Do not routinely target the server,
cluster, firewall, access resources, or individual prerequisites.

```bash
terraform plan -destroy -out=destroy.tfplan
terraform show destroy.tfplan
terraform apply destroy.tfplan
```

The SCP API cannot cancel the server contract. The server module intentionally
does not detach or delete its firewall policy on Terraform destroy, because
doing so would expose an externally-owned server. Remove the policy manually
only after the contract is intentionally retired.

## Development

```bash
terraform fmt -check -diff -recursive modules

for dir in modules/*/; do
  terraform -chdir="$dir" init -backend=false
  terraform -chdir="$dir" validate
done

ansible-galaxy collection install -r requirements.yml
ansible-playbook --syntax-check -i 'localhost,' modules/setup_cluster/system_update.yaml
ansible-playbook --syntax-check -i 'localhost,' modules/setup_cluster/configure_dns.yaml
ansible-playbook --syntax-check -i 'localhost,' modules/setup_cluster/install_k3s.yaml
ansible-playbook --syntax-check -i 'localhost,' modules/setup_cluster/publish_k3s_oidc.yaml
```

Install Python dependencies from `requirements.txt`. The OIDC publication
controller also requires the `azwi` executable.
