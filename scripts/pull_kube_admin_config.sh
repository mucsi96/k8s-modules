#!/bin/bash

mkdir -p .kube
az keyvault secret show --vault-name p05 --name k8s-admin-config --query value --output tsv > .kube/admin-config