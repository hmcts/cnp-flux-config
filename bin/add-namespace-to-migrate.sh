#!/usr/bin/env bash

for FILE in $( find . -name 'namespace*'); do

NAMESPACE=$(yq r "$FILE" metadata.name)

rm -rf "$FILE"


MODULES_DIR="./common-overlay/${NAMESPACE}"
[[ ! -d "$MODULES_DIR" ]] && mkdir -p "$MODULES_DIR"

# -----------------------------------------------------------
(
cat <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: $NAMESPACE
bases:
- ../../../namespaces/$NAMESPACE/namespace.yaml
- ../../../aat/common/$NAMESPACE/identity.yaml
EOF
) > "${MODULES_DIR}/kustomization.yaml"
# -----------------------------------------------------------
yq w -i ${MODULES_DIR}/../kustomization.yaml "bases[+]" $NAMESPACE
done