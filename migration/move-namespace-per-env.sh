#!/usr/bin/env bash
set -ex

# Example of script ./migration/move-namespace-per-env.sh perftest aac
# Run first ./migration/create-namespaces-per-env.sh perftest aac
# Sample based of https://github.com/hmcts/cnp-flux-config/pull/18858/files & https://github.com/hmcts/cnp-flux-config/pull/18862
ENV=$1
NAMESPACE=$2

# Remove namespace ownership from v1 file
if [ -d "k8s/$ENV/common-overlay/$NAMESPACE" ]; then
for file in $(grep -lr "kind: Kustomization" k8s/$ENV/common-overlay/$NAMESPACE); do

    yq eval 'del(.patchesJson6902)' -i $file
    yq 'del( .bases[] | select(. == "*namespace.yaml") )' -i $file
    yq 'del( .bases[] | select(. == "*nonprod-role.yaml") )' -i $file

    if [ "${ENV}"  != "prod" ]
    then
      # add non-prod role to flux v2 environment
      NAMESPACE_PATH="../../../rbac/nonprod-role.yaml" yq eval -i '.resources += [env(NAMESPACE_PATH)]' apps/$NAMESPACE/$ENV/base/kustomization.yaml
      # add AAD Group to base kustomize
      AAD_GROUP_ID=$(kubectl get rolebinding -n $NAMESPACE nonprod-team-permissions -o jsonpath='{.subjects[0].name}')
      yq eval -i '.spec.postBuild.substitute += {"TEAM_AAD_GROUP_ID": "'$AAD_GROUP_ID'"}' apps/$NAMESPACE/base/kustomize.yaml

    fi

    # Remove roleBinding from v1
    # yq -i 'select(.metadata.namespace != "ts")' k8s/namespaces/admin/flux-helm-operator/rbac/$ENV-role-binding.yaml
done
fi
