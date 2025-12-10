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
ASO_RESOURCE_URL=$(yq eval '.resources[0]' apps/azureserviceoperator-system/aso/kustomization.yaml)
ASO_VERSION=$(echo "$ASO_RESOURCE_URL" | cut -d'/' -f8)
kubeconform_config=("-summary" "-n" "12" "-schema-location" "default" "-schema-location" "/tmp/schemas/$ENVIRONMENT/$CLUSTER/")
ASO_URL="https://github.com/Azure/azure-service-operator/releases/download/"$ASO_VERSION"/azureserviceoperator_customresourcedefinitions_"$ASO_VERSION".yaml"
CSI_URL="https://raw.githubusercontent.com/kubernetes-sigs/secrets-store-csi-driver/master/deploy/secrets-store.csi.x-k8s.io_secretproviderclasses.yaml"

curl -sL https://raw.githubusercontent.com/yannh/kubeconform/master/scripts/openapi2jsonschema.py > /tmp/openapi2jsonschema.py

split_files() {
    local source_dir="$1"
    local file_name="$2"
    local destination_dir="${3:-$source_dir}"

    mkdir -p "$destination_dir"

    (
        cd "$destination_dir"
        yq -s '.kind + "-" + .metadata.name' "$source_dir/$file_name"
    )
    rm -rf "$source_dir/$file_name"
}

if [[ -d "clusters/$ENVIRONMENT/$CLUSTER" ]]; then
    TMP_DIR="/tmp/ccd/$ENVIRONMENT/$CLUSTER/"
    CLUSTER_DIR="${TMP_DIR}cluster"
    CCD_OUTPUT_DIR="${TMP_DIR}ccd-manifests"
    mkdir -p "$TMP_DIR" "$CLUSTER_DIR" "$CCD_OUTPUT_DIR"

    yq ". *= load(\"apps/flux-system/${ENVIRONMENT}/${CLUSTER}/kustomize.yaml\")" apps/flux-system/base/kustomize.yaml > "${TMP_DIR}/kustomize.yaml"

    flux build kustomization flux-system --path "./clusters/${ENVIRONMENT}/${CLUSTER}" --kustomization-file "$TMP_DIR/kustomize.yaml" --dry-run > "$TMP_DIR/${CLUSTER}.yaml"
    split_files "$TMP_DIR" "${CLUSTER}.yaml" "$CLUSTER_DIR"

    for NAMESPACE_KUSTOMIZATION in $(find "$CLUSTER_DIR" -type f -iname "Kustomization-*"); do
        NAMESPACE_KUSTOMIZATION_PATH=$(yq '.spec.path' "$NAMESPACE_KUSTOMIZATION")
        NAMESPACE_KUSTOMIZATION_NAME=$(yq '.metadata.name' "$NAMESPACE_KUSTOMIZATION")

        if [[ "$NAMESPACE_KUSTOMIZATION_NAME" != "ccd" && "$NAMESPACE_KUSTOMIZATION_PATH" != *"/apps/ccd/"* ]]; then
            continue
        fi

        flux build kustomization "$NAMESPACE_KUSTOMIZATION_NAME" --path "$NAMESPACE_KUSTOMIZATION_PATH" --kustomization-file "$NAMESPACE_KUSTOMIZATION" --dry-run > "$TMP_DIR/${NAMESPACE_KUSTOMIZATION_NAME}-output.yaml"
        split_files "$TMP_DIR" "${NAMESPACE_KUSTOMIZATION_NAME}-output.yaml" "$CCD_OUTPUT_DIR"
    done

    SCHEMAS_DIR="/tmp/schemas/$ENVIRONMENT/$CLUSTER/master-standalone-strict"
    mkdir -p "$SCHEMAS_DIR"

    if compgen -G "${CLUSTER_DIR}/CustomResourceDefinition-*" > /dev/null; then
        mv "${CLUSTER_DIR}"/CustomResourceDefinition-* "$SCHEMAS_DIR"
    fi

    if compgen -G "${CCD_OUTPUT_DIR}/CustomResourceDefinition-*" > /dev/null; then
        mv "${CCD_OUTPUT_DIR}"/CustomResourceDefinition-* "$SCHEMAS_DIR"
    fi

    # Generate schemas for CRDs used by CCD HelmReleases.
    ./kustomize build --load-restrictor LoadRestrictionsNone apps/admin/traefik-crds > ${TMP_DIR}CustomResourceDefinition-traefik.yaml
    ./kustomize build --load-restrictor LoadRestrictionsNone apps/monitoring/kube-prometheus-stack-crds > ${TMP_DIR}CustomResourceDefinition-kube-prometheus-stack.yaml
    ./kustomize build --load-restrictor LoadRestrictionsNone apps/dynatrace/dynatrace-crds > ${TMP_DIR}CustomResourceDefinition-dynatrace.yaml

    mv "${TMP_DIR}"CustomResourceDefinition-* "$SCHEMAS_DIR"
    cd "$SCHEMAS_DIR"

    export FILENAME_FORMAT='{kind}-{group}-{version}'

    curl -sL  "$ASO_URL" > CustomResourceDefinition-azureserviceoperator.yaml
    curl -sL  "$CSI_URL" > CustomResourceDefinition-secretproviderclasses.yaml

    python3 /tmp/openapi2jsonschema.py * > /dev/null
    rm -rf CustomResourceDefinition-*
    cd "$CURRENT_DIRECTORY"

    if compgen -G "${CCD_OUTPUT_DIR}/*" > /dev/null; then
        kubeconform "${kubeconform_config[@]}" "$CCD_OUTPUT_DIR"
    else
        echo "No CCD manifests generated; skipping kubeconform."
    fi
fi
