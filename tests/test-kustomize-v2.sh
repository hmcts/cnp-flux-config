#!/usr/bin/env bash
set -x

curl -s "https://raw.githubusercontent.com/\
kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" -o install_kustomize.sh && chmod +x install_kustomize.sh && ./install_kustomize.sh 3.7.0

ENVIRONMENTS="sbox sbox-intsvc preview ptl-intsvc"
EXCLUDE_APPS='example-exclude|flux-system'

for ENVIRONMENT in $(echo ${ENVIRONMENTS}); do
kustomizepaths=()

    for FOLDER_FIND in $(find apps -type d -name "$ENVIRONMENT" | grep -Ev "$EXCLUDE_APPS"); do

        FOLDER_SEARCH=$(find $FOLDER_FIND -maxdepth 1 -type d | sed 's@.*/@@')

        if [[ $FOLDER_SEARCH =~ "00" && $FOLDER_SEARCH =~ "01" ]]
        then
            kustomizepaths+=("$FOLDER_FIND/00")
            kustomizepaths+=("$FOLDER_FIND/01")
        elif [[ $FOLDER_SEARCH =~ "00" || $FOLDER_SEARCH =~ "01" ]]
        then
            [[ $FOLDER_SEARCH =~ "00" ]] && kustomizepaths+=("$FOLDER_FIND/00") || kustomizepaths+=("$FOLDER_FIND/01") 
        elif [[ $FOLDER_SEARCH =~ "base" ]]
        then
            kustomizepaths+=("$FOLDER_FIND/base")
        fi

    done

        for path in "${kustomizepaths[@]}"; do
        ./kustomize build --load_restrictor none $path >/dev/null
        if [ $? -eq 1 ]
        then
        echo "Kustomize failing for env $path" && exit 1
        fi
        done

done

aat_whitelist_helm_release_pattern="aat-docmosis"
# prod_whitelist_helm_release_pattern="docmosis"

for env in $(echo "aat prod"); do
env_white_list=${env}_whitelist_helm_release_pattern

  for helm_release in $(echo ${!env_white_list}); do

    for path in $(echo "clusters/ptl-intsvc/base"); do
  
      kustomize_check=$(./kustomize build --load_restrictor none $path | \
      helm_release_name="${helm_release}" yq eval 'select(.metadata and .kind == "ImagePolicy" and .metadata.name == env(helm_release_name) )' -)

      [[ $kustomize_check == "" ]] && true || false

      if [ $? -eq 1 ]
        then
          
        echo $kustomize_check | grep 'hmcts.github.com/prod-automated: disabled'

        if [ $? -eq 1 ]
        then
          echo "Non whitelisted HelmReleases found with hmcts.github.com/prod-automated annotation in ImagePolicy: $helm_release" && exit 1
        fi

      fi

      done

  done
  
done