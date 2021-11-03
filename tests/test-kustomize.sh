#!/usr/bin/env bash
set -x

curl -s "https://raw.githubusercontent.com/\
kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" -o install_kustomize.sh && chmod +x install_kustomize.sh && ./install_kustomize.sh 4.4.0


kustomizepaths=(
    k8s/aat/cluster-00-overlay
    k8s/aat/cluster-01-overlay
    k8s/aat/common-overlay
    k8s/demo/cluster-00-overlay
    k8s/demo/cluster-01-overlay
    k8s/demo/common-overlay
    k8s/ithc/cluster-00-overlay
    k8s/ithc/cluster-01-overlay
    k8s/ithc/common-overlay
    k8s/perftest/cluster-00-overlay
    k8s/perftest/cluster-01-overlay
    k8s/perftest/common-overlay
    k8s/prod/cluster-00-overlay
    k8s/prod/cluster-01-overlay
    k8s/prod/common-overlay
)

for path in "${kustomizepaths[@]}"; do
    ./kustomize build --load_restrictor none $path >/dev/null
    if [ $? -eq 1 ]
    then
     echo "Kustomize failing for env $path" && exit 1
    fi
done

# Keep --- in below, only required once
aat_whitelist_helm_release_pattern='ccd-logstash-*|---|docmosis'
prod_whitelist_helm_release_pattern="ccd-logstash-*|---|docmosis"

for env in $(echo "aat prod"); do
env_white_list=${env}_whitelist_helm_release_pattern

    for path in $(echo "k8s/$env/cluster-00-overlay k8s/$env/cluster-01-overlay k8s/$env/common-overlay"); do

    KUSTOMIZE_OUTPUT=$(./kustomize build --load_restrictor none $path | \
    yq eval 'select(.kind == "HelmRelease" and .metadata.annotations."hmcts.github.com/prod-automated" == "disabled")' - | yq eval '.metadata.name' - )
    HELMRELEASE_CHECK=$(echo "$KUSTOMIZE_OUTPUT" | grep -Ev "${!env_white_list}")

    if [ "$HELMRELEASE_CHECK" == null ] || [ "$HELMRELEASE_CHECK" == "" ]
    then 
        false
    fi


    if [ $? -eq 0 ]
    then
      echo "Non whitelisted HelmReleases found with hmcts.github.com/prod-automated annotation in $path" && exit 1
    fi

    done

done