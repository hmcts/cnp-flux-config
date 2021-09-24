#!/usr/bin/env bash
set -ex

NAMESPACE="$1"
ENVIRONMENT="$2"

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


if [ ! -d "apps/$NAMESPACE/$ENVIRONMENT" ]; then
  
  echo "Creating $ENVIRONMENT for $NAMESPACE"
  mkdir apps/$NAMESPACE/$ENVIRONMENT/
  mkdir apps/$NAMESPACE/$ENVIRONMENT/base
  (
cat <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - $BASE_PATH
namespace: $NAMESPACE
EOF
) > "apps/$NAMESPACE/$ENVIRONMENT/base/kustomization.yaml"
fi

NAMESPACE_PATH="../../../apps/$NAMESPACE/base/kustomize.yaml" yq eval -i '.resources += [env(NAMESPACE_PATH)]' clusters/$ENVIRONMENT/base/kustomization.yaml