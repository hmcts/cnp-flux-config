#!/bin/bash

ENV=dev
VAULT=cftapps-${ENV}
mkdir -p k8s/$ENV/common/sealed-secrets/
CLIENT_ID=$(az keyvault secret show --vault-name ${VAULT} --name aks-sp-app-id --query value -o tsv)
CLIENT_SECRET=$(az keyvault secret show --vault-name ${VAULT} --name aks-sp-app-password --query value -o tsv)

kubectl create secret generic external-dns --from-literal AZURE_TENANT_ID=531ff96d-0ae9-462a-8d2d-bec7c0b42082 \
  --from-literal AZURE_CLIENT_ID=${CLIENT_ID} --from-literal AZURE_CLIENT_SECRET=${CLIENT_SECRET} \
  --dry-run=client \
  -o json > /tmp/external-dns.json

kubeseal --format=yaml --cert=k8s/preview/pub-cert.pem < /tmp/external-dns.json > k8s/preview/common/sealed-secrets/external-dns.yaml