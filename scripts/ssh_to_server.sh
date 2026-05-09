#!/bin/bash

set -euo pipefail

# Reads connection details straight from Terraform state — the authoritative
# source on the machine that ran `terraform apply`. Key Vault mirrors are kept
# for tooling that cannot read state, but this script bypasses them so a stale
# pre-refactor `host` secret cannot send SSH at the wrong box.

if ! command -v terraform >/dev/null 2>&1; then
  echo "terraform is required but not installed." >&2
  exit 1
fi

ssh_host=${SSH_HOST:-$(terraform output -raw hcloud_ipv4_address)}
ssh_user=${SSH_USER:-$(terraform output -raw hcloud_ssh_user)}
ssh_port=${SSH_PORT:-$(terraform output -raw hcloud_ssh_port)}

if [ -z "$ssh_host" ] || [ -z "$ssh_user" ] || [ -z "$ssh_port" ]; then
  echo "Could not read host / user / port from terraform output. Has the cluster been applied?" >&2
  exit 1
fi

# Use a per-invocation ssh-agent so the private key never lands on disk and
# the parent shell's agent (if any) is not mutated. Killed on exit.
eval "$(ssh-agent -s)" >/dev/null
trap 'ssh-agent -k >/dev/null 2>&1 || true' EXIT
terraform output -raw hcloud_ssh_private_key | ssh-add - >/dev/null 2>&1

ssh \
  -p "$ssh_port" \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  "$ssh_user@$ssh_host" \
  "$@"
