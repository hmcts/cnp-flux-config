#!/usr/bin/env bash
set -e

# Example of script ./migration/create-namespaces-per-env.sh perftest camunda
ENVIRONMENT=$1
NAMESPACE=$2
 
if [[ $NAMESPACE == "kube-"* ]] || [[ $NAMESPACE == "default" ]]; 
then
  echo "skipping $NAMESPACE"
  exit 0
fi
if [ ! -d "apps/$NAMESPACE/$ENVIRONMENT" ]; then

  echo "Creating $ENVIRONMENT for $NAMESPACE"
  mkdir apps/$NAMESPACE/$ENVIRONMENT/
  mkdir apps/$NAMESPACE/$ENVIRONMENT/base
  (
cat <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../base
namespace: $NAMESPACE
EOF
) > "apps/$NAMESPACE/$ENVIRONMENT/base/kustomization.yaml"
fi

if [[ $(NAMESPACE=$NAMESPACE yq '.resources | has("../../../apps/env(NAMESPACE)/base/kustomize.yaml")' clusters/$ENVIRONMENT/base/kustomization.yaml) ]]
then
  NAMESPACE_PATH="../../../apps/$NAMESPACE/base/kustomize.yaml" yq eval -i '.resources += [env(NAMESPACE_PATH)]' clusters/$ENVIRONMENT/base/kustomization.yaml
fi
echo "done"