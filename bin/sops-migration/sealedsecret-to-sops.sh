#!/usr/bin/env bash

cd "$(dirname "$0")"

# script that migrates sealedSecrets to sops secrets

# script searches for sealedSecret files
# gets the name and namespace of the sealedsecret
# searches for the k8s secret
# creates a temp file locally with the secret information
# it encrypts the secret using sops and overwrites the current sealedSecret file
# deletes the temp file

# it is then down to the user of the script to commit and push the sops files to GitHub

env=${1}

valid_envs=(ithc preview demo sbox prod ptl-intsvc sbox-intsvc aat perftest)
if [[ -z ${env} ]]; then
  echo "Environment missing! Pass environment as argument. Example: '${0} sbox'"
  exit 1
elif [[ ! ${1} =~ ^(ithc|preview|demo|sbox|prod|ptl-intsvc|sbox-intsvc|aat|perftest)$ ]]; then
  echo "Environment ${env} not valid. Should be one of the following";
  for env in "${valid_envs[@]}"; do
    echo "- $env"
  done
  exit 1
fi

echo "Env is ${env}"
config_file=config.json
kube_context=$(jq -r ".\"${env}\".context" ${config_file})
sops_key=$(jq -r ".\"${env}\".key" ${config_file})

echo "Current kube context is ${kube_context} "
if [[ ! $(kubectl config get-contexts "${kube_context}" -o name) ]]; then
  echo "trying admin..."
  if [[ ! $(kubectl config get-contexts "${kube_context}-admin" -o name ) ]]; then
     echo "Couldn't find ${kube_context}-admin context either. Please authenticate with cluster."
     echo "Example: az aks get-credentials --resource-group cft-${env}-00-rg --name cft-${env}-00-aks --subscription {{subscription}}"
     exit 1
  else
    kube_context=${kube_context}-admin
    echo "admin context found. continuing..."
  fi
fi

sealed_secret_files=$(find ../.. -type f -name "*" -path "*/${env}/*" -exec grep --files-with-matches --ignore-case "sealedSecret" {} \;)

# additional logic for preview as a single file isn't in an environment specific folder
# apps/civil/civil-servicebus/civil-work-allocation-secret.yaml
if [[ "${env}" == "preview" ]] && [[ $(grep -s sealedSecret ../../apps/civil/civil-servicebus/civil-work-allocation-secret.yaml) ]]; then
  sealed_secret_files="${sealed_secret_files} \n../../apps/civil/civil-servicebus/civil-work-allocation-secret.yaml"
fi

if [[ ${sealed_secret_files} == "" ]]; then
  echo "No sealedSecret files found. Nothing to do"
  exit 0
fi

for file in ${sealed_secret_files}; do
  echo -e "\n\n####### "$file" ########"

  file_path=$(dirname "${file}")
  file_name=$(basename "${file}")
  temp_file="${file_path}/k8s-${file_name}"
  name=$(yq '.metadata.name' "${file}" )
  namespace=$(yq '.metadata.namespace' "${file}" )

  if [[ ! $(kubectl get secret -n "${namespace}" "${name}" --context "${kube_context}" -o name) ]]; then
    echo "Secret ${name} not found, checking if any deployments are using the secret.."
    if [[ ! $(kubectl get deployments.apps -n "${namespace}" -o yaml | grep -i "${name}") ]]; then
      echo "Secret ${name} in the ${namespace} namespace doesn't look like it's used by any deployment and can probably be deleted."
      continue
    fi
  fi
  kubectl get secret -n "${namespace}" "${name}" --context "${kube_context}" -o json | jq 'del(.metadata.uid,.metadata.ownerReferences,.metadata.creationTimestamp,.metadata.resourceVersion)' > "${temp_file}"

  sops --encrypt --encrypted-regex '^(data|stringData)$' --azure-kv "${sops_key}" "${temp_file}" > "${file}"
  yq eval -I 2 --inplace "${file}"

  rm -rf "${temp_file}"

  # Uncomment if you would like to just do one secret at a time.
  #break
done

