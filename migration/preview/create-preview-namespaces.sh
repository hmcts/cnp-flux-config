#!/usr/bin/env bash
set -e

# Running on preview as every probable namespace should be here.

for namespace in $(kubectl get ns -A -o jsonpath={.items[*].metadata.name} | xargs -n1 | grep -Ev "monitoring|default|kube-*|catalog|admin|etcd|flux-system|kured" | sort -u | xargs); do
  
if [[ $namespace == "kube-"* ]] || [[ $namespace == "default" ]]; 
then
  echo "skipping $namespace"
  continue
fi
git clean -f apps/$namespace/preview
if [ ! -d "apps/$namespace/preview" ]; then
  
  echo "Creating preview for $namespace"
  mkdir apps/$namespace/preview/
  mkdir apps/$namespace/preview/base
  (
cat <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../../base    # This is apps/base instead of apps/$namespace/base as preview doesn't install everything
namespace: $namespace
EOF
) > "apps/$namespace/preview/base/kustomization.yaml"
fi

NAMESPACE_PATH="../../../apps/$namespace/base/kustomize.yaml" yq eval -i '.resources += [env(NAMESPACE_PATH)]' clusters/preview/base/kustomization.yaml
done