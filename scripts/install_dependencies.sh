#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status

# Detect if running on Ubuntu
if [ "$(uname -s)" = "Linux" ] && [ -f /etc/os-release ]; then
    . /etc/os-release
    if [ "$ID" = "ubuntu" ]; then
        echo "Running on Ubuntu. Checking dependencies..."

        # Check and install azure-cli
        if ! command -v az &> /dev/null; then
            echo "Installing Azure CLI..."
            curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
        else
            echo "Azure CLI is already installed."
        fi

        # Check and install terraform
        if ! command -v terraform &> /dev/null; then
            echo "Installing Terraform..."
            sudo snap install terraform --classic
        else
            echo "Terraform is already installed."
        fi

        # Check and install helm
        if ! command -v helm &> /dev/null; then
            echo "Installing Helm..."
            sudo snap install helm --classic
        else
            echo "Helm is already installed."
        fi

        # Check and install NodeJS
        if ! command -v node &> /dev/null; then
            echo "Installing NodeJS..."
            sudo snap install node --classic
        else
            echo "NodeJS is already installed."
        fi

    fi
fi

# Check if backend.tf exists
if [ ! -f backend.tf ]; then
    echo "Fetching backend configuration from Key Vault..."
    az keyvault secret show \
      --vault-name p06 \
      --name remote-backend-config \
      --query value \
      --output tsv > backend.tf
    echo "Backend configuration saved to backend.tf."

    echo "Initializing Terraform..."
    terraform init --upgrade
else
    echo "Backend configuration already exists."
fi

# Add the Helm repository

helm repo add mucsi96 https://mucsi96.github.io/k8s-helm-charts

source .venv/bin/activate

python3 -m pip install -r requirements.txt

ansible-galaxy collection install -r requirements.yml

python3 -m pip install -r ~/.ansible/collections/ansible_collections/azure/azcollection/requirements.txt
