#!/bin/bash

set -euo pipefail

# Ensure Terraform runs within the project virtualenv for provider plugins.
source .venv/bin/activate

terraform destroy -target=module.setup_cluster.ansible_playbook.firewall 
