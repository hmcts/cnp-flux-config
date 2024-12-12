#!/usr/bin/env bash
# set -ex

NAMESPACE='${NAMESPACE}'
ENVIRONMENT='${ENVIRONMENT}'
NAMESPACE_NAME="$1"
APP_NAME="$2"
APPS_DIR="../../apps/"
CLUSTERS_DIR="../../clusters"

PASSWORD=$(openssl rand -base64 15)

function usage() {
  echo 'usage: ./postgres-setup.sh <namespace> <app_name>'
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
kind: FlexibleServersConfiguration
metadata:
  name: extensions
  namespace: ${NAMESPACE}
  annotations:
    serviceoperator.azure.com/reconcile-policy: detach-on-delete
spec:
  owner:
    name: ${NAMESPACE}-${ENVIRONMENT}
  azureName: azure.extensions
  source: user-override
  value: "btree_gin"
EOF
  ) >"apps/$NAMESPACE_NAME/preview/aso/$NAMESPACE_NAME-postgres-config.yaml"

  (
    cat <<EOF
apiVersion: dbforpostgresql.azure.com/v1api20210601
kind: FlexibleServer
metadata:
  name: ${NAMESPACE}-${ENVIRONMENT}
  namespace: ${NAMESPACE}
spec:
  version: "14"
  network:
    delegatedSubnetResourceReference:
      armId: /subscriptions/8b6ea922-0862-443e-af15-6056e1c9b9a4/resourceGroups/cft-preview-network-rg/providers/Microsoft.Network/virtualNetworks/cft-preview-vnet/subnets/postgresql
    privateDnsZoneArmResourceReference:
      armId: /subscriptions/1baf5470-1c3e-40d3-a6f7-74bfbce4b348/resourceGroups/core-infra-intsvc-rg/providers/Microsoft.Network/privateDnsZones/privatelink.postgres.database.azure.com
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
) >"apps/$NAMESPACE_NAME/preview/sops-secrets/$APP_NAME-values.enc.yaml"

if ! [ -f /usr/local/bin/sops ]; then
  echo "Sops is not installed... installing..."
  curl -LO https://github.com/getsops/sops/releases/download/v3.9.1/sops-v3.9.1.darwin.amd64
  mv sops-v3.9.1.darwin.amd64 /usr/local/bin/sops
  chmod +x /usr/local/bin/sops
fi

sops --encrypt --azure-kv https://dcdcftappsdevkv.vault.azure.net/keys/sops-key/aedb9ea38954430ca1d0a46ed589c049 --encrypted-regex "^(data|stringData)$" --in-place apps/$NAMESPACE_NAME/preview/sops-secrets/$APP_NAME-values.enc.yaml

(
  cat <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - $APP_NAME-postgres.enc.yaml
namespace: $NAMESPACE_NAME
EOF
) >"apps/$NAMESPACE_NAME/preview/sops-secrets/kustomization.yaml"
