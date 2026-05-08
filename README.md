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
| `cloudflare-account-id` | Cloudflare account ID |
| `cloudflare-api-token` | Cloudflare API token for DNS and tunnel management |
| `cloudflare-team-domain` | Cloudflare Zero Trust team domain |
| `authorized-as` | Authorized identity/email for SSO access policies |
| `twingate-api-token` | Twingate API token with Read, Write & Provision permissions |
| `twingate-network` | Twingate network name (e.g. `mynetwork` from `mynetwork.twingate.com`) |
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
`ssh-add` and never written to disk. The script also stages a per-apply
`known_hosts` file under `$XDG_RUNTIME_DIR` (tmpfs) and exports its path as
`TF_VAR_known_hosts_file`; Ansible runs with
`StrictHostKeyChecking=accept-new` against that file, so the host key is
recorded on first connect and re-verified on every subsequent connect for
the rest of the apply, with no impact on `~/.ssh/known_hosts`. Both the
agent and the runtime dir are torn down on script exit.

Run `terraform apply` through `scripts/create.sh` (or set `SSH_AUTH_SOCK`
and `TF_VAR_known_hosts_file` yourself) — applies fail fast if
`SSH_AUTH_SOCK` is unset.

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
