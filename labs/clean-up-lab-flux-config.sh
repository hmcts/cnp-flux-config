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
NAMESPACE_DIR="../apps/${NAMESPACE}"
COMPONENT_DIR="${NAMESPACE_DIR}/${PRODUCT}-${COMPONENT}"
ENVIRONMENT="sbox"

cd "$(dirname "$0")"

function usage() {
  echo 'Missing component name - this should be your GitHub username'
  echo 'usage: ./clean-up-lab-flux-config <component>'
}

function clean_up() {

  # Delete lab folder 
  if [ ! -d "${COMPONENT_DIR}" ]; then
    echo "${COMPONENT_DIR} does not exist."
    exit 1
  else
    rm -rf ${COMPONENT_DIR}
  fi

  # Remove reference to imagePolicy and imageRepo
  FILE_PATH="../${PRODUCT}-${COMPONENT}/image-policy.yaml" yq eval -i 'del( .resources[] | select( . == env(FILE_PATH)) )' ${NAMESPACE_DIR}/automation/kustomization.yaml
  FILE_PATH="../${PRODUCT}-${COMPONENT}/image-repo.yaml" yq eval -i 'del( .resources[] | select( . == env(FILE_PATH)) )' ${NAMESPACE_DIR}/automation/kustomization.yaml

  # Remove reference to lab HR
  NAMESPACE_PATH="../../${PRODUCT}-${COMPONENT}/${PRODUCT}-${COMPONENT}.yaml" yq eval -i 'del( .resources[] | select( . == env(NAMESPACE_PATH)) )' ${NAMESPACE_DIR}/sbox/base/kustomization.yaml  

}

if [ -z "${COMPONENT}" ]
then
  usage
  exit 1
else
  clean_up
fi