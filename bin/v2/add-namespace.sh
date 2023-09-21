#!/usr/bin/env bash
# set -ex
function usage() {
  echo "Please ensure you have added your team's config to https://github.com/hmcts/cnp-jenkins-config/blob/master/team-config.yml"
  echo 'usage: ./add-namespace.sh --product <product> --team-aad-group-id <team-aad-groupid>'
}

# Use flags to set vars
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --product)
        PRODUCT="$2"
        shift 
        shift
        ;;
        --team-aad-group-id)
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

if [ -z "${PRODUCT}" ] 
then
  usage
  exit 1
fi

# Fetch team entry based on product name
YAML_OBJECT=$(curl https://raw.githubusercontent.com/hmcts/cnp-jenkins-config/master/team-config.yml | yq .${PRODUCT})

# Check yaml object is returned
if [ "$YAML_OBJECT" == null ]; then
  echo "Error: YAML_OBJECT is empty. Unable to retrieve data from the URL."
  exit 1
fi

NAMESPACE=$(echo "$YAML_OBJECT" | yq .namespace)
SLACK_CHANNEL=$(echo "$YAML_OBJECT" | yq .slack.contact_channel)

# Check these have been set
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
