#!/usr/bin/env bash
set -ex

curl -s "https://raw.githubusercontent.com/\
kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"  | bash


kustomizepaths=(
    k8s/aat/cluster-00-overlay
    k8s/aat/cluster-01-overlay
    k8s/cftptl/cluster-00-overlay
    k8s/demo/cluster-00-overlay
    k8s/demo/cluster-01-overlay
    k8s/ldata/cluster-00-overlay
    k8s/ldata/cluster-01-overlay
    k8s/preview/cluster-00-overlay
    k8s/preview/cluster-01-overlay
    k8s/ithc/cluster-00-overlay
    k8s/ithc/cluster-01-overlay
    k8s/mgmt-sandbox/cluster-00-overlay
    k8s/perftest/cluster-00-overlay
    k8s/perftest/cluster-01-overlay
    k8s/prod/cluster-00-overlay
    k8s/prod/cluster-01-overlay
    k8s/sandbox/cluster-00-overlay
    k8s/sandbox/cluster-01-overlay
    k8s/sandbox/common-overlay
)

for path in "${kustomizepaths[@]}"; do
    ./kustomize build --load_restrictor none $path >/dev/null
done
