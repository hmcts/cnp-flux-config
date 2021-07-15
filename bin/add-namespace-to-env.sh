#!/usr/bin/env bash

NAMESPACE="$1"
ENV="$2"
AAD_TEAM_GROUP_NAME="$3"

function usage() {
  echo 'usage: ./add-namespace-to-env.sh <namespace> <env> <"aad_team_group_name">'
}

if [ -z "${NAMESPACE}" ] || [ -z "${ENV}" ]
then
  usage
  exit 1
fi

AAD_TEAM_OBJECTID=$(az ad group list --query "[?displayName=='${AAD_TEAM_GROUP_NAME}'].objectId" -o tsv )
if [ -z "${AAD_TEAM_OBJECTID}" ] ; then
  echo "Azure AD Team Group Name not found"
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
NAMESPACE=$NAMESPACE yq eval '.bases += env(NAMESPACE)' -i ${MODULES_DIR}/../kustomization.yaml

if [ "${ENV}" != "prod" ]
then

# -----------------------------------------------------------
(
cat <<EOF
- ../../../namespaces/all-namespaces/nonprod-role.yaml
patchesJson6902:
- target:
    group: rbac.authorization.k8s.io
    version: v1
    kind: RoleBinding
    name: nonprod-team-permissions
    namespace: $NAMESPACE
  patch: |-
    - op: add
      path: "/subjects"
      value:
        - apiGroup: rbac.authorization.k8s.io
          kind: Group
          name: "$AAD_TEAM_OBJECTID"
EOF
) >> "${MODULES_DIR}/kustomization.yaml"
# -----------------------------------------------------------

fi