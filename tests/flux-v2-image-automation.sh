#!/usr/bin/env bash
set -ex -o pipefail

curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" -o install_kustomize.sh
chmod +x install_kustomize.sh
rm -rf kustomize
./install_kustomize.sh 3.7.0

EXCLUSIONS=(
  apps/docmosis/docmosis/docmosis.yaml
  apps/docmosis/docmosis/aat.yaml
  apps/docmosis/docmosis/sbox.yaml
  apps/flux-system/base/image-automation-components.yaml
  apps/idam/idam-api/preview.yaml
  apps/idam/idam-api/sbox.yaml
  apps/idam/idam-web-admin/preview.yaml
  apps/idam/idam-web-admin/ithc.yaml
  apps/idam/idam-web-admin/sbox.yaml
  apps/idam/idam-web-public/preview.yaml
  apps/idam/idam-web-public/sbox.yaml
  apps/idam/idam-testing-support-api/preview.yaml
  apps/idam/idam-testing-support-api/sbox.yaml
  apps/probate/probate-cron-make-dormant-cases/probate-cron-make-dormant-cases.yaml
  apps/probate/probate-cron-reactivate-dormant-cases/probate-cron-reactivate-dormant-cases.yaml
  apps/probate/*
  apps/sscs/sscs-tribunals-frontend/*
  .*demo.*.yaml
  apps/*/*/demo
  apps/*/demo
  .*perftest.*.yaml
  .*ithc.*.yaml
)

for location in apps; do
  image_policies=()
  for file in $(grep -lr "imagepolicy" $location | grep -Ev "$(IFS="|"; echo "${EXCLUSIONS[*]}")"); do
    if [ $(yq eval '.kind' $file) != "HelmRelease" ]; then
      continue
    fi
    image_policies+=($(grep -o "flux-system:.*" $file | cut -d ':' -f2 | sed 's/..$//'))
  done

  ./kustomize build --load_restrictor none "clusters/ptl-intsvc/base" | yq eval 'select(.metadata and .kind == "ImagePolicy")' - > imagepolicies_list.yaml
  [ $? -eq 0 ] || (echo "Kustomize build has failed" && exit 1)

  for policy in "${image_policies[@]}"; do
    echo "Checking image policy: $policy"
    if ! yq eval --arg policy "$policy" '.metadata and .kind == "ImagePolicy" and .metadata.name == $policy and .spec.filterTags.pattern == "^prod-[a-f0-9]+-(?P<ts>[0-9]+)"' imagepolicies_list.yaml >/dev/null 2>&1; then
      echo "Non whitelisted pattern found in ImagePolicy: $policy it should be ^prod-[a-f0-9]+-(?P<ts>[0-9]+)" && exit 1
    fi
  done
done