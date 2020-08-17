#!/usr/bin/env bash

NAMESPACE="$1"
TEAM_SLACK_CHANNEL="$2"

function usage() {
  echo "usage: ./add-namespace.sh <namespace> <team-slack-channel>"
}

if [ -z "${NAMESPACE}" ] || [ -z "${TEAM_SLACK_CHANNEL}" ]
then
  usage
  exit 1
fi

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

MODULES_DIR="${SCRIPT_DIR}/../k8s/namespaces/${NAMESPACE}"
[[ ! -d "$MODULES_DIR" ]] && mkdir -p "$MODULES_DIR"

# -----------------------------------------------------------
(
cat <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: $NAMESPACE
  labels:
    slackChannel: $TEAM_SLACK_CHANNEL
    hmcts.github.com/envInjector: enabled
EOF
) > "${MODULES_DIR}/namespace.yaml"
# -----------------------------------------------------------

# -----------------------------------------------------------
(
cat <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: $NAMESPACE
bases:
- namespace.yaml
# Warning : Adding a file here, adds to all environments to which you add your kustomization.
EOF
) > "${MODULES_DIR}/kustomization.yaml"
# -----------------------------------------------------------



