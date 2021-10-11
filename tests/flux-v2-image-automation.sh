#!/usr/bin/env bash
set -x

curl -s "https://raw.githubusercontent.com/\
kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" -o install_kustomize.sh && chmod +x install_kustomize.sh && ./install_kustomize.sh 3.7.0

EXCLUSIONS_LIST=(
  apps/docmosis/docmosis/docmosis.yaml
  apps/docmosis/docmosis/aat.yaml
  apps/docmosis/docmosis/demo.yaml
  apps/docmosis/docmosis/ithc.yaml
  apps/docmosis/docmosis/perftest.yaml
  apps/docmosis/docmosis/sbox.yaml
  apps/flux-system/base/image-automation-components.yaml
  apps/idam/idam-api/preview.yaml
  apps/idam/idam-api/sbox.yaml
  apps/idam/idam-web-admin/preview.yaml
  apps/idam/idam-web-admin/sbox.yaml
  apps/idam/idam-web-public/preview.yaml
  apps/idam/idam-web-public/sbox.yaml
  k8s/namespaces/docmosis/docmosis/aat.yaml
  *demo.yaml
  k8s/demo/*
  *perftest.yaml
  k8s/perftest/*
  k8s/ithc/*
  *ithc.yaml
)

EXCLUSIONS=$(IFS="|" ; echo "${EXCLUSIONS_LIST[*]}")
FILE_LOCATIONS="apps k8s"

for FILE_LOCATION in $(echo ${FILE_LOCATIONS}); do

    IMAGE_POLICIES=()
    for FILE in $(grep -lr "imagepolicy" $FILE_LOCATION | grep -Ev "$EXCLUSIONS" ); do

        if [ $(yq eval '.kind' $FILE) != "HelmRelease" ] 
        then
            continue 
        fi

        IFS=$'\n'
        IMAGE_POLICIES+=($(grep -o "flux-system:.*" $FILE | cut -d ':' -f2 | sed 's/..$//'))

    done

    ./kustomize build --load_restrictor none "clusters/ptl-intsvc/base" | yq eval 'select(.metadata and .kind == "ImagePolicy")' -  > imagepolicies_list.yaml

    for IMAGE_POLICY in "${IMAGE_POLICIES[@]}"; do

        echo "Checking image policy: $IMAGE_POLICY"

        for path in $(echo "clusters/ptl-intsvc/base"); do

        IMAGE_AUTOMATION=$(cat imagepolicies_list.yaml | \
        IMAGE_POLICY_NAME="${IMAGE_POLICY}" yq eval 'select(.metadata and .kind == "ImagePolicy" and .metadata.name == env(IMAGE_POLICY_NAME) )' -)



            if [ "$IMAGE_AUTOMATION" == "" ]
            then
                echo "No ImagePolicy for $IMAGE_POLICY in clusters/ptl-intsvc/base"
                IMAGE_AUTOMATION=false
            else
                IMAGE_AUTOMATION=true
            fi
            
            if [ "$IMAGE_AUTOMATION" == true ]
            then
            IMAGE_AUTOMATION_CHECK=$(cat imagepolicies_list.yaml  | \
            IMAGE_POLICY_NAME="${IMAGE_POLICY}" yq eval 'select(.metadata and .kind == "ImagePolicy" and .metadata.name == env(IMAGE_POLICY_NAME) )' - | yq eval '.spec.filterTags.pattern == "^prod-[a-f0-9]+-(?P<ts>[0-9]+)"' -)

            if [ $IMAGE_AUTOMATION_CHECK == false ]
            then
                echo "Non whitelisted pattern found in ImagePolicy: $IMAGE_POLICY it should be ^prod-[a-f0-9]+-(?P<ts>[0-9]+)" && exit 1
            fi
        
            fi
        
        done

    done

  done
