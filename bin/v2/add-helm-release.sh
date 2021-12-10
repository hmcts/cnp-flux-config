#!/usr/bin/env bash
set -ex

NAMESPACE=${1}
PRODUCT=${2}
COMPONENT=${3}
ACR=${4}
NAMESPACE_DIR="../../apps/${NAMESPACE}"
COMPONENT_DIR="${NAMESPACE_DIR}/${PRODUCT}-${COMPONENT}"
APPLICATION=${5}
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
  echo 'Usage: ./add-helm-release.sh <namespace> <product> <component> <ACR> <application> <environment>'
}

if [ -z "${COMPONENT}" ] || [ -z "${PRODUCT}" ] || [ -z "${COMPONENT}" ] || [ -z "${ACR}" ] || [ -z "${APPLICATION}" ] || [ -z "${ENVIRONMENT}" ]; then
  usage
  exit 1
fi

if [[ ${APPLICATION} == java ]]; then
  INGRESS_HOST="${PRODUCT}-${COMPONENT}-{{ .Values.global.environment }}.service.core-compute-{{ .Values.global.environment }}.internal"
elif [[ ${APPLICATION} == nodejs ]]; then
  INGRESS_HOST="${PRODUCT}-${COMPONENT}-{{ .Values.global.environment }}.platform.hmcts.net"
else
  echo "Application type not recognised please use java or nodejs"
fi

# Create HR for lab
(
cat <<EOF
---
apiVersion: helm.toolkit.fluxcd.io/v2beta1
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
    ${APPLICATION}:
      image: hmctssandbox.azurecr.io/${PRODUCT}/${COMPONENT}:latest # {"\$imagepolicy": "flux-system:${PRODUCT}-${COMPONENT}"}
      ingressHost: ${INGRESS_HOST}
      disableTraefikTls: true
    global:
      environment: ${FULL_ENVIRONMENT_NAME}
      tenantId: "531ff96d-0ae9-462a-8d2d-bec7c0b42082"
EOF
) > "${COMPONENT_DIR}/${PRODUCT}-${COMPONENT}.yaml"

if [[ ${APPLICATION} == "nodejs" ]]; then
  export BACKEND="http://${PRODUCT}-${COMPONENT}-{{ .Values.global.environment }}.service.core-compute-{{ .Values.global.environment }}.internal"
  yq eval -i '(.spec.values.nodejs.environment.RECIPE_BACKEND_URL) = env(BACKEND) ' ${COMPONENT_DIR}/${PRODUCT}-${COMPONENT}.yaml 
fi

# Configure sbox to manage HR resource
export NAMESPACE_PATH="../../${PRODUCT}-${COMPONENT}/${PRODUCT}-${COMPONENT}.yaml"

if [[ $(yq eval '.resources[] | ( . == env(NAMESPACE_PATH))' ${NAMESPACE_DIR}/${ENVIRONMENT}/base/kustomization.yaml) =~ "true" ]]; then
  echo "Reference to ../../${PRODUCT}-${COMPONENT}/${PRODUCT}-${COMPONENT}.yaml already exists ignoring.."
else
  yq eval -i '.resources += [env(NAMESPACE_PATH)]' ${NAMESPACE_DIR}/${ENVIRONMENT}/base/kustomization.yaml
fi
