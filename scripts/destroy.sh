#!/bin/bash

# Two-pass destroy. The first pass is a normal `terraform destroy` and is the
# common path. The second pass exists for one specific recovery case: a
# destroy is in-flight, but the cluster's microk8s went away outside Terraform
# (e.g. an earlier botched apply that left microk8s broken, followed by
# `snap remove microk8s --purge`). The Hetzner VM is still up, but every
# kubernetes_* / helm_release / kubectl_manifest delete call against the
# (now closed) apiserver port fails with "connection refused" and the destroy
# stalls. The underlying objects are gone with the cluster, so the safe
# recovery is to drop those references from state and continue destroying the
# rest (the VM, Key Vault secrets, Azure AD apps, ...).

set -uo pipefail

source .venv/bin/activate

if terraform destroy -auto-approve "$@"; then
  exit 0
fi

echo
echo "First-pass destroy did not complete cleanly. If the failures above are"
echo "'connection refused' against the cluster API, microk8s is gone and the"
echo "kubernetes_/helm_release/kubectl_manifest resources in state cannot be"
echo "deleted via the API. Dropping those from state and retrying."
echo

while read -r addr; do
  [ -z "$addr" ] && continue
  terraform state rm "$addr" || true
done < <(terraform state list | grep -E '\.(kubernetes_[a-z0-9_]+|kubectl_manifest|helm_release)\.' || true)

terraform destroy -auto-approve "$@"
