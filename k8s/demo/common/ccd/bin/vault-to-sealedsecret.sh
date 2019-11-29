#!/bin/bash -x
# Note:  This script is just place holder for now. Do not use


# script to pick up the secret from azure vault from the key provided 
# <eg., ccd-api-gateway-oauth2-client-secret>  and create encrypted secret
# which will be used in Kubernetes cluster. 
# eg, run as follows on Demo
# vault-to-sealedsecret.sh aat /workspace/hmcts/cnp-flux-config/k8s/demo/pub-cert.pem ccd

env=$1
cert=$2
namespace=$3
secrets=(
    'ccd|ccd-api-gateway-oauth2-client-secret'
    'ccd|ccd-admin-web-oauth2-client-secret'
)

for i in "${secrets[@]}"; do
    vault=$(echo "$i" | awk -F'|' '{print $1}')-$env
    name=$(echo "$i" | awk -F'|' '{print $2}')
    secret=$(az keyvault secret show --vault-name $vault --name $name -o tsv --query value)
    #echo ${secret}

    # kubectl delete secret $vault-$name

    kubectl create secret generic $name \
        --from-literal key=$secret \
        --namespace $namespace \
        --dry-run -o json > $name.json

    kubeseal --format=yaml --cert=$cert < $name.json > ../sealed-secrets/$name.yaml

    # rm -f $team-$name.json

done
