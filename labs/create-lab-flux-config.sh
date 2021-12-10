#!/usr/bin/env bash
set -ex

NAMESPACE=labs
PRODUCT=labs
COMPONENT=$1
ACR=hmctssandbox
NAMESPACE_DIR="../apps/${NAMESPACE}"
COMPONENT_DIR="${NAMESPACE_DIR}/${PRODUCT}-${COMPONENT}"
ENVIRONMENT="sbox"
APPLICATION=${2}

cd "$(dirname "$0")"

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
  ../bin/v2/add-image-policies.sh ${NAMESPACE} ${PRODUCT} ${COMPONENT} ${ACR}
  ../bin/v2/add-helm-release.sh ${NAMESPACE} ${PRODUCT} ${COMPONENT} ${ACR} ${APPLICATION} ${ENVIRONMENT}
fi
