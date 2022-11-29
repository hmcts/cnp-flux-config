#!/usr/bin/env bash
# set -ex

# Example ./migration/fluxv2-migration-part1.sh perftest
ENV=$1

git clean -f apps/ clusters/ k8s/
git checkout apps/ clusters/ k8s/
kubectx "cft-$ENV-01-aks-admin"

echo "Starting Fluxv2 Migration Part 1"

for NAMESPACE in $(kubectl get ns -o jsonpath='{.items[*].metadata.name}' | xargs -n1 | sort -u | xargs); do

if [[ $NAMESPACE == "kube-"* ]] || [[ $NAMESPACE == "default" ]] || [[ $NAMESPACE == "flux-system" ]];
then
  echo "skipping $NAMESPACE"
  continue
fi
  ./migration/create-namespaces-per-env.sh $ENV $NAMESPACE || error_exit "ERROR: Unable to complete namespace creation."
  ./migration/move-namespace-per-env.sh $ENV $NAMESPACE || error_exit "ERROR: Unable to move namespace."
  ./migration/identity-migration-v2.sh $ENV $NAMESPACE || error_exit "ERROR: Unable to complete identity migration."
done

echo "Deployment Complete for Fluxv2 Migration Part 1 - please create PR, once approved and merged, run Fluxv2 Migration Part 2"

