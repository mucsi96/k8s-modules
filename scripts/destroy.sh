#!/bin/bash

set -euo pipefail

source .venv/bin/activate

terraform destroy -target=module.setup_cluster.ansible_playbook.secure_private_server

ssh_host=$(az keyvault secret show --vault-name p06 --name "host" --query value --output tsv)
ssh_user=$(az keyvault secret show --vault-name p06 --name "ssh-user-name" --query value --output tsv)
ssh_port=$(az keyvault secret show --vault-name p06 --name "ssh-port" --query value --output tsv)
ssh_key_path="modules/setup_cluster/.generated/${ssh_host}-id_ed25519"
user_password=$(az keyvault secret show --vault-name p06 --name "user-password" --query value --output tsv)
initial_password=$(az keyvault secret show --vault-name p06 --name "ssh-initial-password" --query value --output tsv)
initial_port=$(az keyvault secret show --vault-name p06 --name "ssh-initial-port" --query value --output tsv)

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