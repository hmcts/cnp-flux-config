#!/usr/bin/env bash
# setup env with ENVIRONMENT with the env name /path in flux-config
# Change to corresponding env path

ENVIRONMENT=$1

cd k8s/${ENVIRONMENT}

#Create temporary directory
mkdir tmp

# echo "fetching public cert for kubeseal"
# For new envs fetch kubeseal cert
# kubeseal --fetch-cert --controller-namespace=admin --controller-name=sealed-secrets > pub-cert.pem

#Regenerate Sealed secrets from existing sealed secrets

echo "Regenerating sealed secrets from existing secret"

for ns in $(kubectl get sealedsecret -A | awk '{if(NR>1) print $1}' | sort --unique ); do
  for i in $(kubectl get sealedsecret -n "${ns}" -o json | jq -r '.items[] | .metadata.name'); do
    SECRETNAME=${i}
    kubectl get secret -n ${ns} ${SECRETNAME} -o json > tmp/${ns}-${SECRETNAME}-secret.json
    if [ "$ns" = "admin" ] || [ "$ns" = "kured" ]
    then
      kubeseal --format=yaml --cert=pub-cert.pem <tmp/${ns}-${SECRETNAME}-secret.json> common/sealed-secrets/${SECRETNAME}.yaml
    else
      kubeseal --format=yaml --cert=pub-cert.pem <tmp/${ns}-${SECRETNAME}-secret.json> common/$ns/${SECRETNAME}.yaml
    fi
  done
done

#delete tmp folder
rm -rf tmp

#git commit files
# echo "Attempting to commit files to git"
# git add .

# #git status after changes
# echo "checking git status before commiting"
# git status

# git commit -m "Regenerating Sealed secrets with latest certificate for ${ENVIRONMENT}"
# git push