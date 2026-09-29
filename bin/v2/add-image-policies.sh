#!/usr/bin/env bash
set -ex

NAMESPACE=$1
PRODUCT=$2
COMPONENT=$3
REGISTRY=$4
ACR=${REGISTRY:-hmctsprod}
APPS_DIR="../../apps/"
COMPONENT_DIR="${APPS_DIR}/${NAMESPACE}/${PRODUCT}-${COMPONENT}"

cd "$(dirname "$0")"

function usage() {
  echo 'usage: ./add-image-policies.sh <namespace> <product> <component> [hmctsprod|hmctspublic|hmctssandbox|hmctssbox|hmctsprivate]'
}

if [ -z "${NAMESPACE}" ] || [ -z "${PRODUCT}" ] || [ -z "${COMPONENT}" ]
then
  usage
  exit 1
fi

case "${ACR}" in
  hmctsprod|hmctspublic|hmctssandbox|hmctssbox|hmctsprivate) ;;
  *)
    echo "Unknown registry: ${ACR}"
    usage
    exit 1
    ;;
esac

# Create component dir if it doesn't exist
if [ ! -d "${COMPONENT_DIR}" ]; then
  echo "Creating ${PRODUCT}-${COMPONENT} directory"
  mkdir -p ${COMPONENT_DIR}
fi

(
cat <<EOF
apiVersion: image.toolkit.fluxcd.io/v1
kind: ImagePolicy
metadata:
  name: ${PRODUCT}-${COMPONENT}
spec:
  imageRepositoryRef:
    name: ${PRODUCT}-${COMPONENT}
EOF
) > "${COMPONENT_DIR}/image-policy.yaml"

if [[ ${ACR} == "hmctspublic" ]]
then
(
cat <<EOF
apiVersion: image.toolkit.fluxcd.io/v1
kind: ImageRepository
metadata:
  name: ${PRODUCT}-${COMPONENT}
spec:
  image: ${ACR}.azurecr.io/${PRODUCT}/${COMPONENT}
EOF
) > "${COMPONENT_DIR}/image-repo.yaml"
else
(
cat <<EOF
apiVersion: image.toolkit.fluxcd.io/v1
kind: ImageRepository
metadata:
  name: ${PRODUCT}-${COMPONENT}
  annotations:
    hmcts.github.com/image-registry: ${ACR}
spec:
  image: ${ACR}.azurecr.io/${PRODUCT}/${COMPONENT}
EOF
) > "${COMPONENT_DIR}/image-repo.yaml"
fi


if [ ! -f "${APPS_DIR}/${NAMESPACE}/base/kustomize.yaml" ]
then
    echo "Creating ${NAMESPACE}"
    mkdir -p ${APPS_DIR}/${NAMESPACE}
    mkdir -p ${APPS_DIR}/${NAMESPACE}/base

fi

if [ ! -d "${APPS_DIR}/${NAMESPACE}/automation" ]; then

  echo "Creating automation directory for ${NAMESPACE}"
  mkdir ${APPS_DIR}/${NAMESPACE}/automation
  (
cat <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
EOF
) > "${APPS_DIR}/${NAMESPACE}/automation/kustomization.yaml"

FILE_PATH="../../${NAMESPACE}/automation" yq eval -i '.resources += [env(FILE_PATH)]' ${APPS_DIR}/flux-system/automation/kustomization.yaml

fi

for FILE in image-repo.yaml image-policy.yaml
do
  export FILE_PATH="../${PRODUCT}-${COMPONENT}/${FILE}"
  if [[ $(yq eval '.resources[] | ( . == env(FILE_PATH))' ${APPS_DIR}/${NAMESPACE}/automation/kustomization.yaml) =~ "true" ]]; then
    echo "Reference to ${FILE_PATH} already exists, ignoring.."
  else
    yq eval -i '.resources += [env(FILE_PATH)]' ${APPS_DIR}/${NAMESPACE}/automation/kustomization.yaml
  fi
done
