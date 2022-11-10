#!/usr/bin/env bash
# set -ex

# Example of script ./migration/helmrelease-migrate-v2.sh demo aac
# Run first:
# ./migration/create-namespaces-per-env.sh demo aac
# ./migration/move-namespace-per-env.sh demo aac
# Sample based of https://github.com/hmcts/cnp-flux-config/pull/18863/files
ENV=$1
NAMESPACE=$2

for file in $(yq eval '.patchesStrategicMerge[]' k8s/$ENV/common-overlay/$NAMESPACE/kustomization.yaml); do

    # Getting application name from patchesStrategicMerge of environment
    APPLICATION=$(echo $file | sed 's|./*||'  | cut -d '/' -f6)
    ENV_FILE=$(echo $file | sed 's|.*/||'  | cut -d '/' -f1)

    # Move the env file to fluxv2 folder 
    mv k8s/namespaces/$NAMESPACE/$APPLICATION/$ENV_FILE apps/$NAMESPACE/$APPLICATION/$ENV_FILE
    # Copy application file to fluxv2 folder
    cp k8s/namespaces/$NAMESPACE/$APPLICATION/$APPLICATION.yaml apps/$NAMESPACE/$APPLICATION/

    ## Flux v2
    # add app to base namespace depending on whether app should be in app/base or app/environment/base
    if [[ $(yq '.bases[] | select(. == "*'$APPLICATION'*")' k8s/namespaces/$NAMESPACE/kustomization.yaml) ]]; then

        if [[ -z $(yq '.resources[] | select(. == "*'$APPLICATION'*")' apps/$NAMESPACE/base/kustomization.yaml) ]]; then
            NAMESPACE_PATH="../$APPLICATION/$APPLICATION.yaml" yq eval -i '.resources += [env(NAMESPACE_PATH)]' apps/$NAMESPACE/base/kustomization.yaml
        fi

        if [[ -z $(yq '.patchesStrategicMerge[] | select(. == "*'$APPLICATION'*")' apps/$NAMESPACE/$ENV/base/kustomization.yaml) ]]; then
            NAMESPACE_PATH="../$APPLICATION/$ENV_FILE" yq eval -i '.patchesStrategicMerge += [env(NAMESPACE_PATH)]' apps/$NAMESPACE/$ENV/base/kustomization.yaml
        fi

    else

        if [[ -z $(yq '.resources[] | select(. == "*'$APPLICATION'*")' apps/$NAMESPACE/$ENV/base/kustomization.yaml) ]]; then
            NAMESPACE_PATH="../../$APPLICATION/$ENV_FILE" yq eval -i '.resources += [env(NAMESPACE_PATH)]' apps/$NAMESPACE/$ENV/base/kustomization.yaml
        fi

        if [[ -z $(yq '.patchesStrategicMerge[] | select(. == "*'$APPLICATION'*")' apps/$NAMESPACE/$ENV/base/kustomization.yaml) ]]; then
            NAMESPACE_PATH="../../$APPLICATION/$ENV_FILE" yq eval -i '.patchesStrategicMerge += [env(NAMESPACE_PATH)]' apps/$NAMESPACE/$ENV/base/kustomization.yaml
        fi

    fi

done

    # Run helmrelease-migrate script
    ./migration/helmrelease-migrate.sh apps/$NAMESPACE/$APPLICATION/

    # Remove fluxv1 kustomization for environment
    rm -r k8s/$ENV/common-overlay/$NAMESPACE
    yq 'del( .bases[] | select(. == "$NAMESPACE") )' -i k8s/$ENV/common-overlay/kustomization.yaml
