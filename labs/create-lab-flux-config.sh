#!/usr/bin/env bash
set -ex

NAMESPACE=labs
PRODUCT=labs
COMPONENT=$1
ACR=hmctssandbox
NAMESPACE_DIR="../apps/${NAMESPACE}"
COMPONENT_DIR="${NAMESPACE_DIR}/${PRODUCT}-${COMPONENT}"
ENVIRONMENT="sbox"
CWD=$PWD
APPLICATION=${2}

function usage() {
  echo "Missing an input"
  echo 'Usage: ./create-lab-flux-config.sh <component> <application>'
  echo 'Component name - this should be your GitHub username'
  echo "Application - java or nodejs"
}

if [ -z "${COMPONENT}" ] || [ -z "${APPLICATION}" ]; then
  usage
  exit 1
fi

# Create component dir and files
if [ -d "${COMPONENT_DIR}" ]; then
  echo "Lab directory already exists, run the cleanup script first"
  exit 1
else
  cd ../
  ./bin/v2/add-image-policies.sh ${NAMESPACE} ${PRODUCT} ${COMPONENT} ${ACR}
  cd ${CWD}
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
  name: labs-${COMPONENT}
  namespace: labs
spec:
  releaseName: labs-${COMPONENT}
  chart:
    spec:
      chart: ./stable/labs-${COMPONENT}
      sourceRef:
        kind: GitRepository
        name: hmcts-charts
        namespace: flux-system
      interval: 1m
  values:
    ${APPLICATION}:
      image: hmctssandbox.azurecr.io/labs/${COMPONENT}:latest # {"\$imagepolicy": "flux-system:labs-${COMPONENT}"}
      ingressHost: ${INGRESS_HOST}
      disableTraefikTls: true
    global:
      environment: sandbox
      tenantId: "531ff96d-0ae9-462a-8d2d-bec7c0b42082"
EOF
) > "${COMPONENT_DIR}/${PRODUCT}-${COMPONENT}.yaml"

if [[ ${APPLICATION} == "nodejs" ]]; then
  export BACKEND="http://${PRODUCT}-${COMPONENT}-sandbox.service.core-compute-sandbox.internal"
  yq eval -i '(.spec.values.nodejs.environment.RECIPE_BACKEND_URL) = env(BACKEND) ' ${COMPONENT_DIR}/${PRODUCT}-${COMPONENT}.yaml 
fi

# Configure sbox to manage HR resource
export NAMESPACE_PATH="../../${PRODUCT}-${COMPONENT}/${PRODUCT}-${COMPONENT}.yaml"

if [[ $(yq eval '.spec[] | ( . == env(NAMESPACE_PATH))' ${NAMESPACE_DIR}/${ENVIRONMENT}/base/kustomization.yaml) =~ "true" ]]; then
  echo "Reference to ../../${PRODUCT}-${COMPONENT}/${PRODUCT}-${COMPONENT}.yaml already exists ignoring.."
else
  yq eval -i '.resources += [env(NAMESPACE_PATH)]' ${NAMESPACE_DIR}/${ENVIRONMENT}/base/kustomization.yaml
fi