#!/usr/bin/env bash
set -ex

# Example of script ./migration/sealed-secrets-migrate.sh perftest camunda
ENV=$1
NAMESPACE=$2

for file in $(grep -lr "kind: SealedSecret" k8s/$ENV/common/$NAMESPACE  | grep -Ev "sealed-secrets"); do

    # Creates directory apps/<namespace>/<environment>
    if [ ! -d "apps/$NAMESPACE/$ENV" ]
    then
        mkdir -p apps/$NAMESPACE/$ENV
    fi

    # Creates directory apps/<namespace>/<environment>/base
    if [ ! -d "apps/$NAMESPACE/$ENV/base" ]
    then
        mkdir -p apps/$NAMESPACE/$ENV/base
    fi

    # Creates file apps/<namespace>/<environment>/base/kustomization.yaml
    if [ ! -f "apps/$NAMESPACE/$ENV/base/kustomization.yaml" ]
    then
(
cat <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
EOF
) > "apps/$NAMESPACE/$ENV/base/kustomization.yaml"
fi

    # Creates directory apps/<namespace>/<environment>/sealed-secrets/
    if [ ! -d "apps/$NAMESPACE/$ENV/sealed-secrets" ]
    then
        mkdir -p apps/$NAMESPACE/$ENV/sealed-secrets
    fi

    # If sealed-secret file is not there, then copy to apps/<namespace>/<environment>/sealed-secrets/
    if [ ! -f "apps/$NAMESPACE/$ENV/sealed-secrets/$file" ]
    then
        mv $file apps/$NAMESPACE/$ENV/sealed-secrets/
    fi

    # Create kustomization file apps/<namespace>/<environment>/sealed-secrets/kustomization.yaml
    if [ ! -f "apps/$NAMESPACE/$ENV/sealed-secrets/kustomization.yaml" ]
    then
(
cat <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
EOF
) > "apps/$NAMESPACE/$ENV/sealed-secrets/kustomization.yaml"
fi

# Appends sealed-secrets name to apps/<namespace>/<environment>/sealed-secrets/kustomization.yaml
FILE_NAME=($(echo "$file" | cut -d '/' -f5))
NAMESPACE_PATH=$FILE_NAME yq eval -i '.resources += [env(NAMESPACE_PATH)]' apps/$NAMESPACE/$ENV/sealed-secrets/kustomization.yaml

# Appends sealed-secrets name to apps/<namespace>/<environment>/base/kustomization.yaml
NAMESPACE_PATH_ENVBASE="../sealed-secrets" yq eval -i '.resources += [env(NAMESPACE_PATH_ENVBASE)]' apps/$NAMESPACE/$ENV/base/kustomization.yaml

done

