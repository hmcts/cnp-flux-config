#!/usr/bin/env bash

NAMESPACE="$1"
ENV="$2"

function usage() {
  echo "usage: ./add-namespace-to-env.sh <namespace> <env>"
}

if [ -z "${NAMESPACE}" ] || [ -z "${ENV}" ]
then
  usage
  exit 1
fi

NAMESPACE_PATH=../../../namespaces/$NAMESPACE
if [ "${ENV}"  == "preview" ]
then
    NAMESPACE_PATH=../../../namespaces/$NAMESPACE/namespace.yaml
fi

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

MODULES_DIR="${SCRIPT_DIR}/../k8s/${ENV}/common-overlay/${NAMESPACE}"
[[ ! -d "$MODULES_DIR" ]] && mkdir -p "$MODULES_DIR"

# -----------------------------------------------------------
(
cat <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: $NAMESPACE
bases:
- $NAMESPACE_PATH
EOF
) > "${MODULES_DIR}/kustomization.yaml"
# -----------------------------------------------------------
yq w -i ${MODULES_DIR}/../kustomization.yaml "bases[+]" $NAMESPACE