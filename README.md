# aks-modules
Terraform modules for Azure cloud deployment

## Prerequisites

### Azure Key Vault Secrets

The following secrets must exist in the Azure Key Vault (named after the `environment_name` variable) before creating the cluster:

| Secret Name | Description |
|---|---|
| `hcloud-token` | Hetzner Cloud API token used to provision the cluster server |
| `dns-zone` | DNS zone domain used by all applications |
| `letsencrypt-email` | Email address for Let's Encrypt certificate registration |
| `cloudflare-zone-id` | Cloudflare zone ID for DNS management |
| `cloudflare-api-token` | Cloudflare API token for DNS records, zone settings, Origin CA certificates and rulesets |
| `authorized-as` | Autonomous system number (ASN) allowed through the Cloudflare firewall rules |
| `twingate-api-token` | Twingate API token with Read, Write & Provision permissions |
| `twingate-network` | Twingate network name (e.g. `mynetwork` from `mynetwork.twingate.com`) |
| `operator-email` | Email of the Twingate user granted operator (SSH + K8s API) access. Must resolve to exactly one Twingate user. |
| `github-token` | GitHub personal access token with `repo` scope for setting Actions secrets |

The cluster server is provisioned on Hetzner Cloud by Terraform. SSH keys, port,
and host credentials are generated during `terraform apply` and exported to the
Key Vault as `host`, `ssh-user-name`, `ssh-port`, `ssh-private-key`, and
`ssh-public-key` for downstream tooling (`scripts/ssh_to_server.sh` reads them).
The cloud-init user data bakes in the public key, sets a custom SSH port,
disables password authentication and root login, and grants NOPASSWD sudo to the
bootstrap user so no password is ever generated or rotated by Ansible.

During `terraform apply`, Ansible authenticates via an `ssh-agent` started by
`scripts/create.sh`; the generated private key is piped straight into
`ssh-add` and never written to disk. Ansible runs with
`StrictHostKeyChecking=no` and `UserKnownHostsFile=/dev/null` — the host IP
comes back from the Hetzner Cloud API over TLS seconds before the first
connect, so we trust it without staging a per-apply `known_hosts` file.
Run `terraform apply` through `scripts/create.sh` (or start your own agent
with `eval "$(ssh-agent -s)"` first) — applies fail fast if `SSH_AUTH_SOCK`
is unset.

## Operator access (Twingate-only)

The Hetzner firewall admits **only** port 443 from the Cloudflare edge. SSH (the
randomized port), the Kubernetes API (`16443`), and ICMP are **not** reachable
from the public internet — they are exposed solely through Twingate.

- A host-level Twingate connector (systemd unit `twingate-connector`) is installed
  by cloud-init on first boot (`setup_twingate_connector` provides the tokens). It
  dials out to Twingate; its traffic to the node's own public IP is delivered
  locally and never crosses the cloud firewall, so `https://<publicIP>:16443` and
  SSH keep working for anyone on the Twingate network.
- Humans get access via the terraform-managed `<env>-operators` Twingate group,
  whose sole member is the `operator-email` user. GitHub Actions reach the K8s API
  via a Twingate service account (`twingate-service-key`).
- **You must have the Twingate client connected** to run `terraform apply`
  (the bootstrap keyscan, Ansible, and `remote-exec` all go over Twingate),
  `scripts/ssh_to_server.sh`, or `kubectl`. Both scripts fail fast with a clear
  message if the SSH port is unreachable.

### Break-glass (locked out)

- Open the **Hetzner Cloud Console** web VNC for the server, or add a temporary
  inbound TCP rule for the SSH port under **Firewalls** in the console. Terraform
  reverts any console-added rule on the next apply (desired self-healing).
- If bootstrap fails before the connector registers, inspect
  `/var/log/cloud-init-output.log` via the console, or `-replace` the server and
  re-run `scripts/create.sh`.

### Token rotation

The connector tokens are baked into the server's cloud-init `user_data` (which has
`ignore_changes`), so rotation is done by recreating the server: `-replace` the
`setup_twingate_connector` connector tokens **and**
`module.provision_hetzner_server.hcloud_server.this`, then re-run `create.sh` with
the break-glass console rule handy in case the old connector drops first.

## HTTP routing (Gateway API)

All in-cluster HTTP routing uses the Kubernetes **Gateway API** (`Gateway` +
`HTTPRoute`). Traefik's own `IngressRoute` and `Ingress` providers are **disabled**
(`setup_ingress_controller/traefik.tf`); the Gateway API CRDs (standard channel)
are vendored and applied before Traefik starts. A single `Gateway` in the `traefik`
namespace terminates TLS on its HTTPS listener with the Cloudflare Origin CA cert
and accepts `HTTPRoute`s from all namespaces.

> **App repos must migrate too.** The `hello`, `language`, `training`, and `backup`
> apps define their routes in their **own** Helm chart repos. Because the
> `IngressRoute` provider is now off, those charts must switch to an `HTTPRoute`
> (`parentRefs` → `traefik/traefik`, `sectionName: websecure`, with their hostname)
> or they will 404 after the rebuild.

## Debugging Commands

Useful commands for debugging Kubernetes (MicroK8s) clusters and authorization issues.

### Authorization & RBAC

```sh
# List all permissions the current user has in the current namespace
kubectl auth can-i --list

# List all permissions for a specific user (impersonation)
kubectl auth can-i --list --as=user@example.com

# Check whether a specific action is permitted
kubectl auth can-i create pods --as=user@example.com -n default

# List all permissions for a service account
kubectl auth can-i --list --as=system:serviceaccount:<namespace>:<sa-name>

# Show all ClusterRoleBindings and RoleBindings for a user
kubectl get clusterrolebindings,rolebindings --all-namespaces -o json \
  | jq -r '.items[] | select(.subjects[]?.name=="user@example.com") | "\(.kind)/\(.metadata.name)"'
```

### MicroK8s API Server Configuration (run on the server)

```sh
# Inspect authorization mode and ABAC/RBAC related flags
sudo cat /var/snap/microk8s/current/args/kube-apiserver | grep -E "authorization|abac"

# Show all kube-apiserver arguments
sudo cat /var/snap/microk8s/current/args/kube-apiserver

# Tail kube-apiserver logs
sudo journalctl -u snap.microk8s.daemon-kubelite -f

# Filter API server logs for authorization decisions
sudo journalctl -u snap.microk8s.daemon-kubelite | grep -i "forbidden\|unauthorized"

# Inspect recent OIDC-related log lines (token validation, issuer discovery)
sudo journalctl -u snap.microk8s.daemon-kubelite -n 200 --no-pager | grep -i oidc

# Check MicroK8s status and enabled addons
sudo microk8s status

# Restart MicroK8s after changing apiserver args
sudo microk8s stop && sudo microk8s start
```

### Cluster & Workload Inspection

```sh
# Show cluster info and component health
kubectl cluster-info
kubectl get componentstatuses
kubectl get nodes -o wide

# Describe a problematic pod (events appear at the bottom)
kubectl describe pod <pod-name> -n <namespace>

# Show pod logs (previous container after a crash)
kubectl logs <pod-name> -n <namespace> --previous

# Watch events across the cluster sorted by time
kubectl get events --all-namespaces --sort-by=.lastTimestamp

# Open a debug shell in an existing pod
kubectl exec -it <pod-name> -n <namespace> -- sh

# Run an ephemeral debug container (kubectl >= 1.23)
kubectl debug -it <pod-name> -n <namespace> --image=busybox --target=<container>
```

### Networking

```sh
# Show services and endpoints
kubectl get svc,endpoints -A

# Run a temporary pod to test DNS / connectivity from inside the cluster
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- bash

# Port-forward a service to localhost for ad-hoc testing
kubectl port-forward svc/<service-name> -n <namespace> 8080:80
```

### Certificates & Secrets

```sh
# Decode a secret value
kubectl get secret <secret-name> -n <namespace> -o jsonpath='{.data.<key>}' | base64 -d

# Inspect cert-manager certificates and challenges
kubectl get certificates,certificaterequests,challenges,orders -A
kubectl describe certificate <name> -n <namespace>
```

## Requirements
