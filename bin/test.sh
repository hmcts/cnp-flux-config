#!/usr/bin/env bash
ENV=$1
VAULT_NAME=$2
aks_client_id=$(az keyvault secret show --vault-name $VAULT_NAME --name aks-sp-app-id --query value -o tsv )
aks_client_secret=$(az keyvault secret show --vault-name $VAULT_NAME --name aks-sp-app-password --query value -o tsv )

# -----------------------------------------------------------
(
cat <<EOF
{
  "cloud": "AzurePublicCloud",
  "aadClientId": "$aks_client_id",
  "aadClientSecret": "$aks_client_secret"
}
EOF
) > "/tmp/azure-values.json"
# -----------------------------------------------------------

kubectl create secret generic acr-credentials --from-file=azure.json=/tmp/azure-values.json --namespace admin --dry-run=client -o json > /tmp/azure.json
kubeseal --format=yaml --cert=k8s/$ENV/pub-cert.pem < /tmp/azure.json > k8s/$ENV/common/sealed-secrets/acr-credentials.yaml