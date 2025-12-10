#!/usr/bin/env bash

# -----
# This script dry-runs the CCD namespace kustomizations to generate the manifests.
# It extracts all CRDs from the dry-run output and extracts json schema using a utility.
# Adds any missing schemas which are not directly added to flux config.
# Uses KubeConform (non-strict) to validate the CCD manifests generated above.
# -----

set -ex

ENVIRONMENT=$1
CLUSTER=$2
CURRENT_DIRECTORY=$(pwd)
kubeconform_config=("-summary" "-n" "12" "-schema-location" "default" "-schema-location" "/tmp/schemas/$ENVIRONMENT/$CLUSTER/")

split_files() {
    local file_dir="$1"
    local file_name="$2"

    cd "$file_dir"
    yq -s '.kind + "-" + .metadata.name' "$file_name"
    rm -rf "$file_name"
    cd "$CURRENT_DIRECTORY"
}

if [[ -d "clusters/$ENVIRONMENT/$CLUSTER" ]]; then
    TMP_DIR="/tmp/ccd/$ENVIRONMENT/$CLUSTER/"
    mkdir -p "$TMP_DIR"

    yq ". *= load(\"apps/flux-system/${ENVIRONMENT}/${CLUSTER}/kustomize.yaml\")" apps/flux-system/base/kustomize.yaml > "${TMP_DIR}/kustomize.yaml"

    flux build kustomization flux-system --path "./clusters/${ENVIRONMENT}/${CLUSTER}" --kustomization-file "$TMP_DIR/kustomize.yaml" --dry-run > "$TMP_DIR/${CLUSTER}.yaml"
    split_files "$TMP_DIR" "${CLUSTER}.yaml"

    for NAMESPACE_KUSTOMIZATION in $(find "$TMP_DIR" -type f -iname "Kustomization-*"); do
        NAMESPACE_KUSTOMIZATION_PATH=$(yq '.spec.path' "$NAMESPACE_KUSTOMIZATION")
        NAMESPACE_KUSTOMIZATION_NAME=$(yq '.metadata.name' "$NAMESPACE_KUSTOMIZATION")

        if [[ "$NAMESPACE_KUSTOMIZATION_NAME" != "ccd" && "$NAMESPACE_KUSTOMIZATION_PATH" != *"/apps/ccd/"* ]]; then
            continue
        fi

        flux build kustomization "$NAMESPACE_KUSTOMIZATION_NAME" --path "$NAMESPACE_KUSTOMIZATION_PATH" --kustomization-file "$NAMESPACE_KUSTOMIZATION" --dry-run > "$TMP_DIR/${NAMESPACE_KUSTOMIZATION_NAME}-output.yaml"
        split_files "$TMP_DIR" "${NAMESPACE_KUSTOMIZATION_NAME}-output.yaml"
    done

    kubeconform "${kubeconform_config[@]}" "$TMP_DIR"
fi
