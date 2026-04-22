# Hetzner deployment target

This folder provisions the same Kubernetes/application stack as the root module, but creates and bootstraps a Hetzner VM first.

## Why this exists

- Reuses the existing shared modules (`setup_cluster`, ingress, app modules, etc.).
- Keeps Terraform state separated from the local-machine deployment by using a dedicated working directory (`environments/hetzner`).
- Allows parallel deployments, as each target has its own state file and execution lifecycle.

## Required secrets in Azure Key Vault

All secrets required by the root deployment still apply, plus:

- `hetzner-api-token`: Hetzner API token with permissions to create servers and SSH keys.

## Usage

```bash
cd environments/hetzner
terraform init
terraform plan
terraform apply
```

> Use a dedicated `environment_name` / Key Vault for the Hetzner target to avoid collisions with the local-machine target secrets.
