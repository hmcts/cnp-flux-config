#!/usr/bin/env bash

function check_packages() {

  #check required packages are installed
  packages=(yq)

  for i in ${packages[@]}

  do
    if command -v ${i}; then :
    else
      echo ${i} is missing! Please first install ${i} via brew or your package manager.
      exit 1
    fi
  done
}

check_packages

set -ex

NAMESPACE=labs
PRODUCT=labs
COMPONENT=$1
ACR=hmctssandbox
NAMESPACE_DIR="../apps/${NAMESPACE}"
COMPONENT_DIR="${NAMESPACE_DIR}/${PRODUCT}-${COMPONENT}"
ENVIRONMENT="sbox"
LANGUAGE=${2}

cd "$(dirname "$0")"

function usage() {
  echo "Missing an input"
  echo 'Usage: ./create-lab-flux-config.sh <component> <language>'
  echo 'Component name - this should be your GitHub username'
  echo "Language - java or nodejs"
}

if [ -z "${COMPONENT}" ] || [ -z "${LANGUAGE}" ]; then
  usage
  exit 1
fi

# Create component dir and files
if [ -d "${COMPONENT_DIR}" ]; then
  echo "Lab directory already exists, run the cleanup script first"
  exit 1
else
  ../bin/v2/add-image-policies.sh ${NAMESPACE} ${PRODUCT} ${COMPONENT} ${ACR}
  ../bin/v2/add-helm-release.sh ${NAMESPACE} ${PRODUCT} ${COMPONENT} ${ACR} ${LANGUAGE} ${ENVIRONMENT}
fi

if [[ ${LANGUAGE} == "nodejs" ]]; then
  export BACKEND="http://${PRODUCT}-${COMPONENT}-{{ .Values.global.environment }}.service.core-compute-{{ .Values.global.environment }}.internal"
  # The name of the env var may need to change to something other than 
  # RECIPE_BACKEND_URL depending on what the Golden Path for nodejs looks like
  yq eval -i '(.spec.values.nodejs.environment.RECIPE_BACKEND_URL) = env(BACKEND) ' ${COMPONENT_DIR}/${PRODUCT}-${COMPONENT}.yaml
fi