#!/usr/bin/env bash
set -e

# Example of script ./migration/create-namespaces-per-env.sh perftest 8a07fdcd-6abd-48b3-ad88-ff737a4b9e3c cft-perftest-00-rg cft-perftest-00-aks
ENVIRONMENT=$1
SUBSCRIPTION_ID=$2
AKS_RG=$3
AKS_NAME=$4

# Ensure you are logged into the correct cluster before running.
az aks get-credentials --resource-group $AKS_RG --name $AKS_NAME --subscription $SUBSCRIPTION_ID --overwrite-existing -a

for namespace in $(kubectl get ns -A -o jsonpath={.items[*].metadata.name} | xargs -n1 | grep -Ev "monitoring|default|kube-*|catalog|admin|etcd|flux-system|kured" | sort -u | xargs); do
  
if [[ $namespace == "kube-"* ]] || [[ $namespace == "default" ]]; 
then
  echo "skipping $namespace"
  continue
fi
git clean -f apps/$namespace/$ENVIRONMENT
if [ ! -d "apps/$namespace/$ENVIRONMENT" ]; then
  
  echo "Creating $ENVIRONMENT for $namespace"
  mkdir apps/$namespace/$ENVIRONMENT/
  mkdir apps/$namespace/$ENVIRONMENT/base
  (
cat <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../base
namespace: $namespace
EOF
) > "apps/$namespace/$ENVIRONMENT/base/kustomization.yaml"
fi

NAMESPACE_PATH="../../../apps/$namespace/base/kustomize.yaml" yq eval -i '.resources += [env(NAMESPACE_PATH)]' clusters/$ENVIRONMENT/base/kustomization.yaml
done