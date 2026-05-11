#!/bin/bash

mkdir -p .kube
az keyvault secret show --vault-name p06 --name k8s-oidc-config --query value --output tsv > .kube/oidc-config
