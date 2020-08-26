#!/bin/bash -x

cert=${1:-../../pub-cert.pem}
namespace=${2:-fees-pay}
vault=ccpay-demo
secrets=(
    'pci-pal-account-id-cmc'
    'pci-pal-account-id-probate'
    'pci-pal-account-id-divorce'
    'pci-pal-api-url'
    'pci-pal-api-key'
    'gov-pay-keys-reference'
    'gov-pay-keys-cmc'
    'gov-pay-keys-divorce'
    'gov-pay-keys-probate'
    'liberata-keys-oauth2-client-id'
    'liberata-keys-oauth2-client-secret'
    'liberata-keys-oauth2-username'
    'liberata-keys-oauth2-password'
    'paybubble-idam-client-secret'
)

for name in "${secrets[@]}"; do
    secret=$(az keyvault secret show --vault-name $vault --name $name -o tsv --query value)
    #echo ${secret}

    # kubectl delete secret $vault-$name

    kubectl create secret generic $name \
        --from-literal key=$secret \
        --namespace $namespace \
        --dry-run -o json > $name.json

    mkdir -p sealed-secrets
    kubeseal --format=yaml --cert=$cert < $name.json > $name.yaml

    rm -f $name.json

done

