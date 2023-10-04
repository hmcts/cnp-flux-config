#!/usr/bin/env bash
set -e

declare -A SUBMAP

SUBMAP[aat]="DCD-CNP-DEV"
SUBMAP[perftest]="DCD-CNP-QA"
SUBMAP[demo]="DCD-CNP-DEV"
SUBMAP[ithc]="DCD-CNP-QA"
SUBMAP[prod]="DCD-CNP-Prod"
SUBMAP[sandbox]="DCD-CFT-Sandbox"

function usage() {
  echo 'usage: ./add-wl-identity.sh --namespace <namespace> --mi-name <mi-name>'
}

# Use flags to set vars
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --namespace)
        NAMESPACE="$2"
        shift
        shift
        ;;
        --mi-name)
        WL_IDENTITY_NAME="$2"
        shift
        shift
        ;;
        *)    # unknown option
        echo "Unknown option: $1"
        usage
        exit 1
        ;;
    esac
done

if [ -z "${NAMESPACE}" ]
then
  usage
  exit 1
fi

if [ -z "${WL_IDENTITY_NAME}" ]
then
  WL_IDENTITY_NAME=${NAMESPACE}
fi

if [[ $(yq eval '.resources[] | ( . == "../../base/workload-identity")' apps/${NAMESPACE}/base/kustomization.yaml) =~ "true" ]]; then
  echo "Reference to ../../base/workload-identity already exists in base, ignoring.."
else
  yq eval -i '.resources += "../../base/workload-identity"' apps/${NAMESPACE}/base/kustomization.yaml
fi

if [ -d "apps/${NAMESPACE}/preview" ]; then
  if [[ $(yq eval '.resources[] | ( . == "../../../base/workload-identity")' apps/${NAMESPACE}/preview/base/kustomization.yaml) =~ "true" ]]; then
    echo "Reference to ../../base/workload-identity already exists in preview, ignoring.."
  else
    yq eval -i '.resources += "../../../base/workload-identity"' apps/${NAMESPACE}/preview/base/kustomization.yaml
  fi
fi

WL_IDENTITY_NAME=${WL_IDENTITY_NAME} yq '.spec.postBuild.substitute.WI_NAME = env(WL_IDENTITY_NAME)' -i apps/${NAMESPACE}/base/kustomize.yaml

mkdir -p apps/${NAMESPACE}/serviceaccount
for ENVIRONMENT in "sbox" "preview" "demo" "ithc" "perftest" "aat" "prod"
do
  MI_ENV_NAME=${ENVIRONMENT}
  MI_ENV_SHORT_NAME=${ENVIRONMENT}
  if [ "${ENVIRONMENT}"  == "preview" ]
  then
    MI_ENV_NAME="aat"
    MI_ENV_SHORT_NAME="aat"
  elif [ "${ENVIRONMENT}"  == "sbox" ]
  then
    MI_ENV_NAME="sandbox"
    MI_ENV_SHORT_NAME="sbox"
  fi

  if [ -d "apps/${NAMESPACE}/${ENVIRONMENT}" ]; then
    SA_PATH="path: ../../serviceaccount/${MI_ENV_SHORT_NAME}.yaml" yq eval -i '.patches += [env(SA_PATH)]' apps/${NAMESPACE}/${ENVIRONMENT}/base/kustomization.yaml
    CLIENT_ID=$(az identity show --name ${WL_IDENTITY_NAME}-${MI_ENV_NAME}-mi --resource-group managed-identities-${MI_ENV_NAME}-rg --subscription ${SUBMAP[${MI_ENV_NAME}]} --query clientId -o tsv)
(
cat <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: \${NAMESPACE}
  namespace: \${NAMESPACE}
  annotations:
    azure.workload.identity/client-id: "$CLIENT_ID"
EOF
) > "apps/${NAMESPACE}/serviceaccount/${MI_ENV_SHORT_NAME}.yaml"
  fi
done

