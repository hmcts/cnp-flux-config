#!/usr/bin/env bash
set -ex

NAMESPACE=$1
SLACK_CHANNEL=$2
TEAM_AAD_GROUP_ID=$3

function usage() {
  echo 'usage: ./add-namespace.sh <namespace> <slack-channel> <team-ad-groupid>'
}

if [ -z "${NAMESPACE}" ] || [ -z "${SLACK_CHANNEL}" ] || [ -z "${TEAM_AAD_GROUP_ID}" ]
then
  usage
  exit 1
fi


if [ ! -f "apps/$NAMESPACE/base/kustomize.yaml" ]
then
    echo "Creating $NAMESPACE"
    mkdir -p apps/$NAMESPACE
    mkdir -p apps/$NAMESPACE/base

(
cat <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../base
namespace: $NAMESPACE
EOF
) > "apps/$NAMESPACE/base/kustomization.yaml"

(
cat <<EOF
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: $NAMESPACE
  namespace: flux-system
spec:
  path: ./apps/$NAMESPACE/\${ENVIRONMENT}/base
  postBuild:
    substitute:
      NAMESPACE: "$NAMESPACE"
      TEAM_NOTIFICATION_CHANNEL: "${SLACK_CHANNEL}"
      TEAM_AAD_GROUP_ID: "${TEAM_AAD_GROUP_ID}"
EOF
) > "apps/$NAMESPACE/base/kustomize.yaml"

fi
