#!/usr/bin/env bash
set -ex

NAMESPACE="$1"
ENVIRONMENT="${2:-preview}"
SUBSCRIPTION=${3:-DCD-CNP-DEV}
SOPS_KEY=${4:-https://dcdcftappsdevkv.vault.azure.net/keys/sops-key/aedb9ea38954430ca1d0a46ed589c049}

SERVICE_BUS_NAMESPACE="${NAMESPACE}-sb-${ENVIRONMENT}"
SECRET_FILE_NAME="$SERVICE_BUS_NAMESPACE.enc.yaml"

PRIMARY_KEY=$(az servicebus namespace authorization-rule keys list -n RootManageSharedAccessKey --namespace-name "$SERVICE_BUS_NAMESPACE"  --resource-group "${NAMESPACE}-aso-${ENVIRONMENT}-rg" --subscription "$SUBSCRIPTION"  --query "primaryKey" -o tsv)
CONNECTION_STRING=$(az servicebus namespace authorization-rule keys list -n RootManageSharedAccessKey --namespace-name "$SERVICE_BUS_NAMESPACE"  --resource-group "${NAMESPACE}-aso-${ENVIRONMENT}-rg" --subscription "$SUBSCRIPTION"  --query "primaryConnectionString" -o tsv )

if [ ! -d "apps/${NAMESPACE}/${ENVIRONMENT}/sops-secrets" ]; then

  echo "Creating sops-secrets for ${NAMESPACE} in ${ENVIRONMENT} "
  mkdir apps/${NAMESPACE}/${ENVIRONMENT}/sops-secrets
  (
cat <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - $SERVICE_BUS_NAMESPACE.enc.yaml
namespace: $NAMESPACE
EOF
) > "apps/${NAMESPACE}/${ENVIRONMENT}/sops-secrets/kustomization.yaml"

 yq eval -i '.resources += "../sops-secrets"' apps/${NAMESPACE}/${ENVIRONMENT}/base/kustomization.yaml

elif [ $(SECRET_FILE_NAME="rd-sb-preview.enc.yaml"  yq 'contains({"resources": [env(SECRET_FILE_NAME)]})' apps/rd/preview/sops-secrets/kustomization.yaml) == false ]; then
  SECRET_FILE_NAME="${SECRET_FILE_NAME}" yq eval -i '.resources += [env(SECRET_FILE_NAME)]' apps/${NAMESPACE}/${ENVIRONMENT}/sops-secrets/kustomization.yaml
fi

kubectl create secret generic "$SERVICE_BUS_NAMESPACE" -n "$NAMESPACE" --from-literal connectionString="$CONNECTION_STRING" --from-literal primaryKey="$PRIMARY_KEY"  --type=Opaque -o yaml --dry-run=client > apps/"$NAMESPACE"/"$ENVIRONMENT"/sops-secrets/"$SECRET_FILE_NAME"

sops --encrypt --azure-kv "$SOPS_KEY"  --encrypted-regex "^(data|stringData)$" --in-place apps/"$NAMESPACE"/"$ENVIRONMENT"/sops-secrets/"$SECRET_FILE_NAME"