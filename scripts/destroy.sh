#!/bin/bash

set -euo pipefail

source .venv/bin/activate

CLUSTER="${1:-all}"

destroy_local() {
  terraform destroy -target=module.setup_cluster.ansible_playbook.secure_private_server

  local ssh_host ssh_user ssh_port ssh_key_path user_password initial_password initial_port
  ssh_host=$(az keyvault secret show --vault-name p06 --name "host" --query value --output tsv)
  ssh_user=$(az keyvault secret show --vault-name p06 --name "ssh-user-name" --query value --output tsv)
  ssh_port=$(az keyvault secret show --vault-name p06 --name "local-ssh-port" --query value --output tsv)
  ssh_key_path="modules/setup_cluster/.generated/${ssh_host}-id_ed25519"
  user_password=$(az keyvault secret show --vault-name p06 --name "local-user-password" --query value --output tsv)
  initial_password=$(az keyvault secret show --vault-name p06 --name "ssh-initial-password" --query value --output tsv)
  initial_port=$(az keyvault secret show --vault-name p06 --name "ssh-initial-port" --query value --output tsv)

  ansible-playbook \
    -i "$ssh_host," \
    modules/setup_cluster/revert_secure_private_server.yaml \
    --extra-vars "ansible_user=$ssh_user" \
    --extra-vars "ansible_port=$ssh_port" \
    --extra-vars "ansible_ssh_private_key_file=$ssh_key_path" \
    --extra-vars "user_password=$user_password" \
    --extra-vars "initial_username=$ssh_user" \
    --extra-vars "initial_password=$initial_password" \
    --extra-vars "initial_port=$initial_port"
}

case "$CLUSTER" in
  local)
    destroy_local
    terraform destroy
    ;;
  hetzner)
    terraform destroy
    ;;
  all)
    destroy_local
    terraform destroy
    ;;
  *)
    echo "Usage: $0 [local|hetzner|all]"
    exit 1
    ;;
esac
