#!/usr/bin/env bash

# -----
# This script dry-runs the cluster and namespace kustomizations to generate the manifests.
# It extracts all CRDs from the dry-run output and extracts json schema using a utility.
# Adds any missing schemas which are not directly added to flux config.
# Uses KubeConform to validate all the manifests generated above.
# -----

set -ex

ENVIRONMENT=$1
CLUSTER=$2
CURRENT_DIRECTORY=$(pwd)
ASO_RESOURCE_URL=$(yq eval '.resources[0]' apps/azureserviceoperator-system/aso/kustomization.yaml)
ASO_VERSION=$(echo "$ASO_RESOURCE_URL" | cut -d'/' -f8)
kubeconform_config=("-strict" "-summary" "-n" "12" "-schema-location" "default" "-schema-location" "/tmp/schemas/$ENVIRONMENT/$CLUSTER/")
ASO_URL="https://github.com/Azure/azure-service-operator/releases/download/"$ASO_VERSION"/azureserviceoperator_customresourcedefinitions_"$ASO_VERSION".yaml"
CSI_URL="https://raw.githubusercontent.com/kubernetes-sigs/secrets-store-csi-driver/master/deploy/secrets-store.csi.x-k8s.io_secretproviderclasses.yaml"

curl -sL https://raw.githubusercontent.com/yannh/kubeconform/master/scripts/openapi2jsonschema.py > /tmp/openapi2jsonschema.py

split_files() {
    local file_dir="$1"
    local file_name="$2"

    cd "$file_dir"
    yq -s '.kind + "-" + .metadata.name' "$file_name"
    rm -rf "$file_name"
    cd "$CURRENT_DIRECTORY"
}

run_kubeconform() {
    local attempt=1
    local max_attempts=4
    local retry_delay=20
    local status
    local output_file
    output_file=$(mktemp)

    while true; do
        set +e
        kubeconform "${kubeconform_config[@]}" "$TMP_DIR" 2>&1 | tee "$output_file"
        status=${PIPESTATUS[0]}
        set -e

        if [[ "$status" -eq 0 ]]; then
            rm -f "$output_file"
            return 0
        fi

        if grep -q "received HTTP status 429" "$output_file" && grep -q "Invalid: 0" "$output_file" && [[ "$attempt" -lt "$max_attempts" ]]; then
            echo "Kubeconform schema download was rate limited. Retrying attempt $((attempt + 1))/$max_attempts after ${retry_delay}s..."
            sleep "$retry_delay"
            attempt=$((attempt + 1))
            retry_delay=$((retry_delay * 2))
            continue
        fi

        rm -f "$output_file"
        return "$status"
    done
}

if [[ -d "clusters/$ENVIRONMENT/$CLUSTER" ]]; then
    TMP_DIR="/tmp/$ENVIRONMENT/$CLUSTER/"
    mkdir -p "$TMP_DIR"

    yq ". *= load(\"apps/flux-system/${ENVIRONMENT}/${CLUSTER}/kustomize.yaml\")" apps/flux-system/base/kustomize.yaml > "${TMP_DIR}/kustomize.yaml"

    cat $TMP_DIR/kustomize.yaml
    flux build kustomization flux-system --path "./clusters/${ENVIRONMENT}/${CLUSTER}" --kustomization-file "$TMP_DIR/kustomize.yaml" --dry-run > "$TMP_DIR/${CLUSTER}.yaml"
    split_files "$TMP_DIR" "${CLUSTER}.yaml"

    for NAMESPACE_KUSTOMIZATION in $(find "$TMP_DIR" -type f -iname "Kustomization-*"); do
        NAMESPACE_KUSTOMIZATION_PATH=$(yq '.spec.path' "$NAMESPACE_KUSTOMIZATION")
        NAMESPACE_KUSTOMIZATION_NAME=$(yq '.metadata.name' "$NAMESPACE_KUSTOMIZATION")
        flux build kustomization "$NAMESPACE_KUSTOMIZATION_NAME" --path "$NAMESPACE_KUSTOMIZATION_PATH" --kustomization-file "$NAMESPACE_KUSTOMIZATION" --dry-run > "$TMP_DIR/${NAMESPACE_KUSTOMIZATION_NAME}-output.yaml"
        split_files "$TMP_DIR" "${NAMESPACE_KUSTOMIZATION_NAME}-output.yaml"
    done

    SCHEMAS_DIR="/tmp/schemas/$ENVIRONMENT/$CLUSTER/master-standalone-strict"
    mkdir -p "$SCHEMAS_DIR"

    #hack to get traefik and prometheus CRDs as flux build kustomization is ignoring remote bases.
    kustomize build --load-restrictor LoadRestrictionsNone apps/admin/traefik-crds > ${TMP_DIR}CustomResourceDefinition-treafik.yaml
    kustomize build --load-restrictor LoadRestrictionsNone apps/monitoring/kube-prometheus-stack-crds > ${TMP_DIR}CustomResourceDefinition-kube-prometheus-stack.yaml
    kustomize build --load-restrictor LoadRestrictionsNone apps/dynatrace/dynatrace-crds > ${TMP_DIR}CustomResourceDefinition-dynatrace.yaml

    mv "${TMP_DIR}"CustomResourceDefinition-* "$SCHEMAS_DIR"
    cd "$SCHEMAS_DIR"

    export FILENAME_FORMAT='{kind}-{group}-{version}'

    curl -sL  "$ASO_URL" > CustomResourceDefinition-azureserviceoperator.yaml
    curl -sL  "$CSI_URL" > CustomResourceDefinition-secretproviderclasses.yaml

    python3 /tmp/openapi2jsonschema.py * > /dev/null
    rm -rf CustomResourceDefinition-*
    cd "$CURRENT_DIRECTORY"

    run_kubeconform
fi
