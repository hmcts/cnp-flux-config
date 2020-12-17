#!/usr/bin/env bash
set -x

curl -s "https://raw.githubusercontent.com/\
kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"  | bash


kustomizepaths=(
    k8s/aat/cluster-00-overlay
    k8s/aat/cluster-01-overlay
    k8s/aat/common-overlay
    k8s/cftptl/cluster-00-overlay
    k8s/demo/cluster-00-overlay
    k8s/demo/cluster-01-overlay
    k8s/demo/common-overlay
    k8s/ldata/cluster-00-overlay
    k8s/ldata/cluster-01-overlay
    k8s/preview/cluster-00-overlay
    k8s/preview/cluster-01-overlay
    k8s/preview/common-overlay
    k8s/ithc/cluster-00-overlay
    k8s/ithc/cluster-01-overlay
    k8s/ithc/common-overlay
    k8s/mgmt-sandbox/cluster-00-overlay
    k8s/perftest/cluster-00-overlay
    k8s/perftest/cluster-01-overlay
    k8s/perftest/common-overlay
    k8s/prod/cluster-00-overlay
    k8s/prod/cluster-01-overlay
    k8s/prod/common-overlay
    k8s/sandbox/cluster-00-overlay
    k8s/sandbox/cluster-01-overlay
    k8s/sandbox/common-overlay
)

for path in "${kustomizepaths[@]}"; do
    ./kustomize build --load_restrictor none $path >/dev/null
    if [ $? -eq 1 ]
    then
     echo "Kustomize failing for env $path" && exit 1
    fi
done

aat_whitelist_helm_release_pattern='sample\|another-sample' # Helm Release names seperated by `\|`
prod_whitelist_helm_release_pattern='sample\|another-sample' # Helm Release names seperated by `\|`

for env in $(echo "aat prod"); do
  env_white_list=${env}_whitelist_helm_release_pattern
  for path in $(echo "k8s/$env/cluster-00-overlay k8s/$env/cluster-01-overlay k8s/$env/common-overlay"); do
    ./kustomize build --load_restrictor none $path | yq r  -d'*'  -j - metadata | (grep \"hmcts.github.com/prod-automated\":\"disabled\" || true ) | grep -v ${!env_white_list}
    if [ $? -eq 0 ]
    then
      echo "Non whitelisted HelmReleases found with hmcts.github.com/prod-automated annotation in $path" && exit 1
    fi
  done
done