#!/bin/bash

set -euo pipefail

VAULT_NAME=${AZURE_KEYVAULT_NAME:-p06}
SSH_HOST_SECRET=${SSH_HOST_SECRET:-host}
SSH_USER_SECRET=${SSH_USER_SECRET:-ssh-user-name}
SSH_PORT_SECRET=${SSH_PORT_SECRET:-ssh-port}

get_secret() {
  local secret_name=$1

  az keyvault secret show \
    --vault-name "$VAULT_NAME" \
    --name "$secret_name" \
    --query value \
    --output tsv
}

if ! command -v az >/dev/null 2>&1; then
  echo "Azure CLI (az) is required but not installed." >&2
  exit 1
fi

ssh_host=${SSH_HOST:-$(get_secret "$SSH_HOST_SECRET")}

if [ -z "$ssh_host" ]; then
  echo "Unable to retrieve SSH host from Key Vault." >&2
  exit 1
fi

ssh_user=${SSH_USER:-$(get_secret "$SSH_USER_SECRET")}

if [ -z "$ssh_user" ]; then
  echo "Unable to retrieve SSH user from Key Vault." >&2
  exit 1
fi

ssh_key_path=${SSH_IDENTITY_PATH:-"modules/setup_cluster/.generated/${ssh_host}-id_ed25519"}

if [ ! -f "$ssh_key_path" ]; then
  echo "SSH identity file not found at $ssh_key_path" >&2
  exit 1
fi

chmod 600 "$ssh_key_path"

ssh_port=$(get_secret "$SSH_PORT_SECRET")

if [ -z "$ssh_port" ]; then
  echo "Unable to retrieve SSH port from Key Vault." >&2
  exit 1
fi

ssh \
  -i "$ssh_key_path" \
  -p "$ssh_port" \
  "$ssh_user@$ssh_host" \
  "$@"
