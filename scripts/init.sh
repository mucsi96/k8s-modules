#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status

resourceGroupName=""
provisionWithHetzner="false"

while [ $# -gt 0 ]; do
  case "$1" in
    --hetzner)
      provisionWithHetzner="true"
      shift
      ;;
    -h|--help)
      echo "Usage: $0 <resource-group-name> [--hetzner]"
      exit 0
      ;;
    *)
      if [ -z "$resourceGroupName" ]; then
        resourceGroupName="$1"
      else
        echo "Unexpected argument: $1" >&2
        echo "Usage: $0 <resource-group-name> [--hetzner]" >&2
        exit 1
      fi
      shift
      ;;
  esac
done

if [ -z "$resourceGroupName" ]; then
  echo "Usage: $0 <resource-group-name> [--hetzner]"
  exit 1
fi

ansible-playbook \
  --inventory localhost, \
  --extra-vars "resource_group_name=$resourceGroupName" \
  --extra-vars "provision_with_hetzner=$provisionWithHetzner" \
  scripts/init.yaml

echo "Azure resources for Terraform backend are configured."

terraform init
