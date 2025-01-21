#!/usr/bin/env bash
# set -ex

NAMESPACE='${NAMESPACE}'
ENVIRONMENT='${ENVIRONMENT}'
NAMESPACE_NAME="$1"
APP_NAME="$2"
APPS_DIR="../../apps/"
CLUSTERS_DIR="../../clusters"

PASSWORD=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16 ; echo)
PASSWORD=$(echo -n $PASSWORD | base64 )

function usage() {
  echo 'usage: ./add-postgres-server.sh <namespace> <app_name>'
}

if [ -z "${NAMESPACE_NAME}" ] || [ -z "${APP_NAME}" ]; then
  usage
  exit 1
fi

if [ ! -f "apps/$NAMESPACE_NAME/preview/aso" ]; then
  echo "Creating aso"
  mkdir -p apps/$NAMESPACE_NAME
  mkdir -p apps/$NAMESPACE_NAME/preview
  mkdir -p apps/$NAMESPACE_NAME/preview/aso

  (
    cat <<EOF
apiVersion: dbforpostgresql.azure.com/v1api20210601
kind: FlexibleServer
metadata:
  name: ${NAMESPACE}-${ENVIRONMENT}
  namespace: ${NAMESPACE}
spec:
  version: "14"
  sku:
    name: Standard_D2ds_v5
    tier: GeneralPurpose
EOF
  ) >"apps/$NAMESPACE_NAME/preview/aso/$NAMESPACE_NAME-postgres.yaml"
fi

if [ ! -f "apps/$NAMESPACE_NAME/preview/sops-secrets" ]; then
  echo "Creating sops-secrets"
  mkdir -p apps/$NAMESPACE_NAME
  mkdir -p apps/$NAMESPACE_NAME/preview
  mkdir -p apps/$NAMESPACE_NAME/preview/sops-secrets
fi

(
  cat <<EOF
apiVersion: v1
data:
  PASSWORD: $PASSWORD
kind: Secret
metadata:
    creationTimestamp: null
    name: postgres
    namespace: $NAMESPACE_NAME
type: Opaque
EOF
) >"apps/$NAMESPACE_NAME/preview/sops-secrets/$APP_NAME-values.enc_temp.yaml"

if ! [ -f /usr/local/bin/sops ]; then
  echo "Sops is not installed... installing..."
  curl -LO https://github.com/getsops/sops/releases/download/v3.9.1/sops-v3.9.1.darwin.amd64
  mv sops-v3.9.1.darwin.amd64 /usr/local/bin/sops
  chmod +x /usr/local/bin/sops
fi

sops --encrypt --azure-kv https://dcdcftappsdevkv.vault.azure.net/keys/sops-key/aedb9ea38954430ca1d0a46ed589c049 --encrypted-regex "^(data|stringData)$" --in-place apps/$NAMESPACE_NAME/preview/sops-secrets/$APP_NAME-values.enc_temp.yaml

# making sure the indentation is with 2 spaces
yq eval --indent 2 -P "apps/$NAMESPACE_NAME/preview/sops-secrets/$APP_NAME-values.enc_temp.yaml" > "apps/$NAMESPACE_NAME/preview/sops-secrets/$APP_NAME-values.enc.yaml"

# deleting the temp file
rm "./apps/$NAMESPACE_NAME/preview/sops-secrets/$APP_NAME-values.enc_temp.yaml"

(
  cat <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - $APP_NAME-values.enc.yaml
namespace: $NAMESPACE_NAME
EOF
) >"apps/$NAMESPACE_NAME/preview/sops-secrets/kustomization.yaml"

if [ ! -f "apps/$NAMESPACE_NAME/preview/base/kustomization.yaml" ]; then
  echo "Creating kustomization in preview/base"
  mkdir -p apps/$NAMESPACE_NAME
  mkdir -p apps/$NAMESPACE_NAME/preview
  mkdir -p apps/$NAMESPACE_NAME/preview/base

  (
    cat <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../../base
  - ../../../azureserviceoperator-system/resources/resource-group.yaml
  - ../../../azureserviceoperator-system/resources/flexibleserver-postgres.yaml
  - ../sops-secrets
namespace: $NAMESPACE_NAME
patches:
  - path: ../aso/$NAMESPACE_NAME-postgres.yaml
EOF
  ) >"apps/$NAMESPACE_NAME/preview/base/kustomization.yaml"
else
echo "Updating kustomization in preview/base"
(
    cat <<EOF
  - ../../../azureserviceoperator-system/resources/resource-group.yaml\\
  - ../../../azureserviceoperator-system/resources/flexibleserver-postgres.yaml\\
  - ../../../azureserviceoperator-system/resources/flexibleserver-postgres-config.yaml\\
  - ../sops-secrets
EOF
  ) >"apps/$NAMESPACE_NAME/preview/base/kustomization_resources_temp.yaml"
(
    cat <<EOF
  - path: ../aso/$NAMESPACE_NAME-postgres.yaml
EOF
  ) >"apps/$NAMESPACE_NAME/preview/base/kustomization_patches_temp.yaml"

# Path to the kustomization.yaml file
KUSTOMIZATION_FILE="apps/$NAMESPACE_NAME/preview/base/kustomization.yaml"

# Path to the file to be included
FILE_RESOURCES_TO_INCLUDE="apps/$NAMESPACE_NAME/preview/base/kustomization_resources_temp.yaml"

# Read the contents of the file to be included
FILE_RESOURCES_CONTENTS=$(cat "$FILE_RESOURCES_TO_INCLUDE")

# Path to the file to be included
FILE_PATCHES_TO_INCLUDE="apps/$NAMESPACE_NAME/preview/base/kustomization_patches_temp.yaml"

# Read the contents of the file to be included
FILE_PATCHES_CONTENTS=$(cat "$FILE_PATCHES_TO_INCLUDE")

echo $FILE_RESOURCES_CONTENTS
echo $FILE_PATCHES_CONTENTS

# Update the kustomization.yaml file
sed -i.bak "/namespace:/i\\
$FILE_RESOURCES_CONTENTS
" "$KUSTOMIZATION_FILE"

echo "Updated $KUSTOMIZATION_FILE with contents of $FILE_RESOURCES_TO_INCLUDE"

# Update the kustomization.yaml file
sed -i.bak "/patches:/a\\
$FILE_PATCHES_CONTENTS
" "$KUSTOMIZATION_FILE"

echo "Updated $KUSTOMIZATION_FILE with contents of $FILE_PATCHES_TO_INCLUDE"

# deleting the temp file
rm "./apps/$NAMESPACE_NAME/preview/base/kustomization_resources_temp.yaml"
rm "./apps/$NAMESPACE_NAME/preview/base/kustomization_patches_temp.yaml"
rm "./apps/$NAMESPACE_NAME/preview/base/kustomization.yaml.bak"
fi