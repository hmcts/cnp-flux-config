#!/usr/bin/env bash

set -ex
declare -A SUBMAP

SUBMAP[aat]="DCD-CNP-DEV"
SUBMAP[perftest]="DCD-CNP-QA"
SUBMAP[demo]="DCD-CNP-DEV"
SUBMAP[ithc]="DCD-CNP-QA"
SUBMAP[prod]="DCD-CNP-Prod"
SUBMAP[sbox]="DCD-CFT-Sandbox"

NAMESPACE="$1"
SHORT_NAME="$2"
MI="$3"
ENV="$4"

function usage() {
  echo "usage: ./add-identity-to-env.sh <namespace> <short-name> <mi-name> <env>"
}

if [ -z "${NAMESPACE}" ] || [ -z "${SHORT_NAME}" ] || [ -z "${MI}" ] || [ -z "${ENV}" ]
then
  usage
  exit 1
fi

MI_ENV=${ENV}
if [ "${ENV}"  == "preview" ]
then
    MI_ENV="aat"
    yq eval -i '.resources += "../../identity/identity.yaml"' apps/$NAMESPACE/preview/base/kustomization.yaml
fi


CLIENT_ID=$(az identity show --name ${SHORT_NAME}-${MI_ENV}-mi --resource-group managed-identities-${MI_ENV}-rg --subscription ${SUBMAP[${MI_ENV}]} --query clientId)
RESOURCE_ID=$(az identity show --name ${SHORT_NAME}-${MI_ENV}-mi --resource-group managed-identities-${MI_ENV}-rg --subscription ${SUBMAP[${MI_ENV}]} --query id)

# -----------------------------------------------------------
(
cat <<EOF
apiVersion: "aadpodidentity.k8s.io/v1"
kind: AzureIdentity
metadata:
  name: $SHORT_NAME
  namespace: $NAMESPACE
spec:
  resourceID: $RESOURCE_ID
  clientID: $CLIENT_ID

EOF
) > "apps/${NAMESPACE}/identity/${MI_ENV}.yaml"
# -----------------------------------------------------------

IDENTITY_PATH="../../identity/${MI_ENV}.yaml" yq eval -i '.patchesStrategicMerge += [env(IDENTITY_PATH)]' apps/${NAMESPACE}/${ENV}/base/kustomization.yaml


