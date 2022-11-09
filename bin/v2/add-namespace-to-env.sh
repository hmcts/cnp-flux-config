#!/usr/bin/env bash
set -ex

NAMESPACE="$1"
ENVIRONMENT="$2"
APPS_DIR="../../apps/"
CLUSTERS_DIR="../../clusters"
cd "$(dirname "$0")"

function usage() {
  echo 'usage: ./add-namespace-to-env.sh <namespace> <env>'
}

if [ -z "${NAMESPACE}" ] || [ -z "${ENVIRONMENT}" ]
then
  usage
  exit 1
fi

BASE_PATH=../../base
if [ "${ENVIRONMENT}"  == "preview" ]
then
    BASE_PATH=../../../base
fi

if [ ! -d "${APPS_DIR}/${NAMESPACE}/${ENVIRONMENT}" ]; then
  
  echo "Creating ${ENVIRONMENT} for ${NAMESPACE}"
  mkdir ${APPS_DIR}/${NAMESPACE}/${ENVIRONMENT}/
  mkdir ${APPS_DIR}/$NAMESPACE/${ENVIRONMENT}/base
  (
cat <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - $BASE_PATH
namespace: $NAMESPACE
EOF
) > "${APPS_DIR}/${NAMESPACE}/${ENVIRONMENT}/base/kustomization.yaml"
fi

if [[ "${ENVIRONMENT}"  != "preview" ]] && [[ "${ENVIRONMENT}"  != "prod" ]]; then
  yq eval -i '.resources += "../../../rbac/nonprod-role.yaml"' ${APPS_DIR}/${NAMESPACE}/${ENVIRONMENT}/base/kustomization.yaml
fi

export NAMESPACE_PATH="../../../apps/$NAMESPACE/base/kustomize.yaml"
if [[ $(yq eval '.resources[] | ( . == env(NAMESPACE_PATH))' ${CLUSTERS_DIR}/${ENVIRONMENT}/base/kustomization.yaml) =~ "true" ]]; then
  echo "Reference to ${CLUSTERS_DIR}/${ENVIRONMENT}/base/kustomization.yaml already exists ignoring.."
else
  yq eval -i '.resources += [env(NAMESPACE_PATH)]' ${CLUSTERS_DIR}/${ENVIRONMENT}/base/kustomization.yaml
fi

