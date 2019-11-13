#!/usr/bin/env bash

SUB_MAP=( "aat=DCD-CFTAPPS-STG"
  "perftest=DCD-CFTAPPS-TEST"
)
#  "ithc=DCD-CFTAPPS-ITHC"
#  "prod=DCD-CFTAPPS-PROD"
#  "sbox=DCD-CFTAPPS-SBOX"

NAMESPACE="$1"
SHORT_NAME="$2"
MI="$3"

function usage() {
  echo "usage: ./base-ns-id-gen.sh <namespace> <short-name> <mi-name>"
}

if [ -z "${NAMESPACE}" ] || [ -z "${SHORT_NAME}" ] || [ -z "${MI}" ]
then
  usage
  exit 1
fi

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for i in $(seq 0 1)
do
  e=$(echo ${SUB_MAP[${i}]} |cut -d '=' -f 1)

  MODULES_DIR="${SCRIPT_DIR}/../k8s/${e}/common/${NAMESPACE}"
  [[ ! -d "$MODULES_DIR" ]] && mkdir -p "$MODULES_DIR"

# -----------------------------------------------------------
(
cat <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: $NAMESPACE
---
EOF
) > "${MODULES_DIR}/namespace.yaml"
# -----------------------------------------------------------

CLIENT_ID=$(az identity show --name ${SHORT_NAME}-${e}-mi --resource-group managed-identities-${e}-rg --subscription $(echo ${SUB_MAP[${i}]} |cut -d '=' -f 2) --query clientId)
RESOURCE_ID=$(az identity show --name ${SHORT_NAME}-${e}-mi --resource-group managed-identities-${e}-rg --subscription $(echo ${SUB_MAP[${i}]} |cut -d '=' -f 2) --query id)

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
  ResourceID: $RESOURCE_ID
  ClientID: $CLIENT_ID

---

apiVersion: "aadpodidentity.k8s.io/v1"
kind: AzureIdentityBinding
metadata:
  name: $SHORT_NAME-binding
  namespace: $NAMESPACE
spec:
  AzureIdentity: $SHORT_NAME
  Selector: $SHORT_NAME
EOF
) > "${MODULES_DIR}/identity.yaml"
# -----------------------------------------------------------

done

