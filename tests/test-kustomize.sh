#!/usr/bin/env bash
set -x

curl -s "https://raw.githubusercontent.com/\
kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" -o install_kustomize.sh && chmod +x install_kustomize.sh && ./install_kustomize.sh 3.7.0


kustomizepaths=(
    k8s/aat/cluster-00-overlay
    k8s/aat/cluster-01-overlay
    k8s/aat/common-overlay
    k8s/demo/cluster-00-overlay
    k8s/demo/cluster-01-overlay
    k8s/demo/common-overlay
    k8s/preview/cluster-00-overlay
    k8s/preview/cluster-01-overlay
    k8s/preview/common-overlay
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

aat_whitelist_helm_release_pattern="ccd-logstash-* docmosis"
prod_whitelist_helm_release_pattern="docmosis"

for env in $(echo "aat prod"); do
env_white_list=${env}_whitelist_helm_release_pattern

  for helm_release in $(echo ${!env_white_list}); do

    for path in $(echo "k8s/$env/cluster-00-overlay k8s/$env/cluster-01-overlay k8s/$env/common-overlay"); do
  
      kustomize_check=$(./kustomize build --load_restrictor none $path | \
      helm_release_name="${helm_release}" yq eval 'select(.metadata and .kind == "HelmRelease" and .metadata.name == env(helm_release_name) )' -)

      [[ $kustomize_check == "" ]] && true || false

      if [ $? -eq 1 ]
        then
          
        echo $kustomize_check | grep 'hmcts.github.com/prod-automated: disabled'

        if [ $? -eq 1 ]
        then
          echo "Non whitelisted HelmReleases found with hmcts.github.com/prod-automated annotation in $path" && exit 1
        fi

      fi

      done

  done
  
done