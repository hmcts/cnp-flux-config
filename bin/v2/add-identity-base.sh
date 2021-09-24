#!/usr/bin/env bash

NAMESPACE="$1"
SHORT_NAME="$2"

function usage() {
  echo "usage: ./add-identity-base.sh <namespace> <short-name>"
}

if [ -z "${NAMESPACE}" ] || [ -z "${SHORT_NAME}" ]
then
  usage
  exit 1
fi

mkdir -p apps/$NAMESPACE/identity
# -----------------------------------------------------------
(
cat <<EOF
apiVersion: "aadpodidentity.k8s.io/v1"
kind: AzureIdentity
metadata:
  name: $SHORT_NAME
  namespace: $NAMESPACE
spec:
  type: 0

---

apiVersion: "aadpodidentity.k8s.io/v1"
kind: AzureIdentityBinding
metadata:
  name: $SHORT_NAME-binding
  namespace: $NAMESPACE
spec:
  azureIdentity: $SHORT_NAME
  selector: $SHORT_NAME
EOF
) > "apps/$NAMESPACE/identity/identity.yaml"
# -----------------------------------------------------------

yq eval -i '.resources += "../identity/identity.yaml"' apps/$NAMESPACE/base/kustomization.yaml