#!/bin/bash

set -euo pipefail

# Ensure Terraform runs within the project virtualenv for provider plugins.
source .venv/bin/activate

terraform destroy -target=module.setup_cluster.ansible_playbook.secure_private_server

get_secret() {
  local secret_name=$1

  az keyvault secret show \
    --vault-name p06 \
    --name "$secret_name" \
    --query value \
    --output tsv
}

ssh_host=$(get_secret "host")
ssh_user=$(get_secret "ssh-user-name")
ssh_port=$(get_secret "ssh-port")
ssh_key_path="modules/setup_cluster/.generated/${ssh_host}-id_ed25519"
user_password=$(get_secret "user-password")
initial_password=$(get_secret "ssh-initial-password")
initial_port=$(get_secret "ssh-initial-port")

ansible-playbook \
  -i "$ssh_host," \
  modules/setup_cluster/revert_secure_private_server.yaml \
  --extra-vars "ansible_user=$ssh_user" \
  --extra-vars "ansible_port=$ssh_port" \
  --extra-vars "ansible_ssh_private_key_file=$ssh_key_path" \
  --extra-vars "ansible_become_password=$user_password" \
  --extra-vars "initial_username=$ssh_user" \
  --extra-vars "initial_password=$initial_password" \
  --extra-vars "initial_port=$initial_port"

terraform destroy