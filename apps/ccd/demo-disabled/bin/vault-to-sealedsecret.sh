#!/bin/bash -x
# script to pick up the secret from azure vault from the key provided 
# <eg., ccd-importer-autotest-email>  and create encrypted secret
# which will be used in Kubernetes cluster. 
# eg, run as follows on Demo
# vault-to-sealedsecret.sh demo /workspace/hmcts/cnp-flux-config/clusters/demo/pub-cert.pem ccd

env=$1
cert=$2
namespace=$3
vault=ccd-$env

username=$(az keyvault secret show --vault-name $vault --name ccd-importer-autotest-email -o tsv --query value)
password=$(az keyvault secret show --vault-name $vault --name ccd-importer-autotest-password -o tsv --query value)
idamClientSecret=$(az keyvault secret show --vault-name $vault --name  ccd-admin-web-oauth2-client-secret -o tsv --query value)
kubectl create secret generic importer-creds \
        --from-literal username=$username \
        --from-literal password=$password \
        --from-literal idam-client-secret=$idamClientSecret\
        --namespace $namespace \
        --dry-run -o json > importer-creds.json

kubeseal --format=yaml --cert=$cert < importer-creds.json > ../sealed-secrets/importer-creds.yaml
rm -f importer-creds.json

secrets=(
    'ccd|ccd-api-gateway-oauth2-client-secret'
    'ccd|ccd-admin-web-oauth2-client-secret'
)

for i in "${secrets[@]}"; do
    name=$(echo "$i" | awk -F'|' '{print $2}')
    secret=$(az keyvault secret show --vault-name $vault --name $name -o tsv --query value)
    kubectl create secret generic $name \
        --from-literal key=$secret \
        --namespace $namespace \
        --dry-run -o json > $name.json

    kubeseal --format=yaml --cert=$cert < $name.json > ../$name.yaml
    rm -f $name.json
done
