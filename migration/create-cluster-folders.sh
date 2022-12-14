#!/usr/bin/env bash
set -e

# Running on preview as every probable namespace should be here.
git clean -f apps/ clusters/ k8s/
git checkout apps/ clusters/ k8s/

NAMESPACES="am ccd em fees-pay nfdiv pcq rd sscs wa"
ENVIRONMENTS="aat prod ithc demo perftest preview"
CLUSTERS="00 01"
for NAMESPACE in $NAMESPACES; do
  for ENVIRONMENT in $ENVIRONMENTS; do
    if [ -d "apps/$NAMESPACE/$ENVIRONMENT" ]; then
       for CLUSTER in $CLUSTERS; do
           if [ ! -d "apps/$NAMESPACE/$ENVIRONMENT/$CLUSTER" ]; then

             echo "Creating $ENVIRONMENT-$CLUSTER for $NAMESPACE"
             mkdir apps/$NAMESPACE/$ENVIRONMENT/$CLUSTER
(
cat <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../base
namespace: $NAMESPACE
EOF
)> "apps/$NAMESPACE/$ENVIRONMENT/$CLUSTER/kustomization.yaml"
           fi
       done
       fi
    done
done