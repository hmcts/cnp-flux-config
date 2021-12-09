#!/usr/bin/env bash
set -ex

NAMESPACE=labs
PRODUCT=labs
COMPONENT=$1
ACR=hmctssandbox
NAMESPACE_DIR="../../apps/${NAMESPACE}"
COMPONENT_DIR="${NAMESPACE_DIR}/${PRODUCT}-${COMPONENT}"
ENVIRONMENT="sbox"
CWD=$PWD

function usage() {
  echo 'Missing component name - this should be your GitHub username'
  echo 'usage: ./create-lab-flux-config.sh <component>'
}

if [ -z "${COMPONENT}" ]
then
  usage
  exit 1
fi

# Create component dir and files
if [ -d "${COMPONENT_DIR}" ]; then
  echo "Lab directory already exists, run the cleanup script first"
  exit 1
else
  cd ../../
  ./bin/v2/add-image-policies.sh ${NAMESPACE} ${PRODUCT} ${COMPONENT} ${ACR}
  cd ${CWD}
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
    java:
      image: hmctssandbox.azurecr.io/labs/${COMPONENT}:latest #{"\$imagepolicy": "flux-system:labs-${COMPONENT}"}
      ingressHost: labs-${COMPONENT}-{{ .Values.global.environment }}.service.core-compute-{{ .Values.global.environment }}.internal
      disableTraefikTls: true
    global:
      environment: sandbox
      tenantId: "531ff96d-0ae9-462a-8d2d-bec7c0b42082"
EOF
) > "${COMPONENT_DIR}/${PRODUCT}-${COMPONENT}.yaml"


# Configure sbox to manage HR resource
export NAMESPACE_PATH="../../${PRODUCT}-${COMPONENT}/${PRODUCT}-${COMPONENT}.yaml"

if [[ $(yq eval '.resources[] | ( . == env(NAMESPACE_PATH))' ../../apps/labs/sbox/base/kustomization.yaml) =~ "true" ]]
then
  echo "Reference to ../../${PRODUCT}-${COMPONENT}/${PRODUCT}-${COMPONENT}.yaml already exists ignoring.."

else
  yq eval -i '.resources += [env(NAMESPACE_PATH)]' ${NAMESPACE_DIR}/${ENVIRONMENT}/base/kustomization.yaml
fi