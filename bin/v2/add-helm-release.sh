#!/usr/bin/env bash
set -ex

NAMESPACE=${1}
PRODUCT=${2}
COMPONENT=${3}
ACR=${4}
NAMESPACE_DIR="../../apps/${NAMESPACE}"
COMPONENT_DIR="${NAMESPACE_DIR}/${PRODUCT}-${COMPONENT}"
LANGUAGE=${5}
ENVIRONMENT=${6}

cd "$(dirname "$0")"

if [ ! -d "${NAMESPACE_DIR}/${ENVIRONMENT}" ]; then
  echo "${ENVIRONMENT} folder not found... creating"
  ./add-namespace-to-env.sh ${NAMESPACE} ${ENVIRONMENT}
fi


if [[ ${ENVIRONMENT} == sbox ]]; then
    FULL_ENVIRONMENT_NAME="sandbox"
else
    FULL_ENVIRONMENT_NAME="${ENVIRONMENT}"
fi

function usage() {
  echo 'Usage: ./add-helm-release.sh <namespace> <product> <component> <ACR> <language> <environment>'
}

if [ -z "${COMPONENT}" ] || [ -z "${PRODUCT}" ] || [ -z "${COMPONENT}" ] || [ -z "${ACR}" ] || [ -z "${LANGUAGE}" ] || [ -z "${ENVIRONMENT}" ]; then
  usage
  exit 1
fi

# Create HR for lab
(
cat <<EOF
---
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: ${PRODUCT}-${COMPONENT}
  namespace: ${NAMESPACE}
spec:
  releaseName: ${PRODUCT}-${COMPONENT}
  chart:
    spec:
      chart: ./stable/${PRODUCT}-${COMPONENT}
      sourceRef:
        kind: GitRepository
        name: hmcts-charts
        namespace: flux-system
      interval: 1m
  values:
    ${LANGUAGE}:
      image: hmctssandbox.azurecr.io/${PRODUCT}/${COMPONENT}:latest # {"\$imagepolicy": "flux-system:${PRODUCT}-${COMPONENT}"}
      disableTraefikTls: true
EOF
) > "${COMPONENT_DIR}/${PRODUCT}-${COMPONENT}.yaml"

# Configure sbox to manage HR resource
export NAMESPACE_PATH="../../${PRODUCT}-${COMPONENT}/${PRODUCT}-${COMPONENT}.yaml"

if [[ $(yq eval '.resources[] | ( . == env(NAMESPACE_PATH))' ${NAMESPACE_DIR}/${ENVIRONMENT}/base/kustomization.yaml) =~ "true" ]]; then
  echo "Reference to ../../${PRODUCT}-${COMPONENT}/${PRODUCT}-${COMPONENT}.yaml already exists ignoring.."
else
  yq eval -i '.resources += [env(NAMESPACE_PATH)]' ${NAMESPACE_DIR}/${ENVIRONMENT}/base/kustomization.yaml
fi
