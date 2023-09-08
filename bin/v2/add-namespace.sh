#!/usr/bin/env bash
# set -ex
function usage() {
  echo 'usage: ./add-namespace.sh --namespace <namespace> --slack-channel <slack-channel> --team-aad-group-id <team-ad-groupid>'
}

# Use flags to set vars
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --namespace)
        NAMESPACE="$2"
        shift
        shift
        ;;
        --slack-channel)
        SLACK_CHANNEL="$2"
        shift
        shift 
        ;;
        --product)
        PRODUCT="$2"
        shift 
        shift
        ;;
        --team-aad-groupid)
        TEAM_AAD_GROUP_ID="$2"
        shift 
        shift
        ;;
        *)    # unknown option
        echo "Unknown option: $1"
        usage
        exit 1
        ;;
    esac
done

if [ -z "${NAMESPACE}" ] || [ -z "${SLACK_CHANNEL}" ] || [ -z "${TEAM_AAD_GROUP_ID}" ]
then
  usage
  exit 1
fi

# Product defaults to namespace if not set
if [ -z "${PRODUCT}" ] 
then
  PRODUCT=${NAMESPACE}
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
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: $NAMESPACE
  namespace: flux-system
spec:
  path: ./apps/$NAMESPACE/\${ENVIRONMENT}/base
  postBuild:
    substitute:
      NAMESPACE: "$NAMESPACE"
      WI_NAME: "$PRODUCT"
      TEAM_NOTIFICATION_CHANNEL: "${SLACK_CHANNEL}"
      TEAM_AAD_GROUP_ID: "${TEAM_AAD_GROUP_ID}"
EOF
) > "apps/$NAMESPACE/base/kustomize.yaml"

fi
