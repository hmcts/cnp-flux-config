#!/usr/bin/env bash

EXCLUDE_APPS='example-exclude|flux-system'

for FOLDER_FIND in $(find apps -type d -name "automation" | grep -Ev "$EXCLUDE_APPS"); do

    IMAGE_POLICY_FILE=$(cat $FOLDER_FIND/kustomization.yaml | yq '.resources[] | select(. == "*image-policy.yaml")' | sed -r 's/.{2}//')
    for path in ${IMAGE_POLICY_FILE[@]}; do

        if [[ ! -f "$(dirname $FOLDER_FIND)$path" ]]
            then
                echo "Image policy file $(dirname $FOLDER_FIND)$path is missing" && exit 1
            else
                echo "Image policy file $(dirname $FOLDER_FIND)$path exists"
        fi
    done

    IMAGE_REPO_FILE=$(cat $FOLDER_FIND/kustomization.yaml | yq '.resources[] | select(. == "*image-repo.yaml")' | sed -r 's/.{2}//')
    for path in ${IMAGE_REPO_FILE[@]}; do

        if [[ ! -f "$(dirname $FOLDER_FIND)$path" ]]
            then
                echo "Image policy file $(dirname $FOLDER_FIND)$path is missing" && exit 1
            else
                echo "Image policy file $(dirname $FOLDER_FIND)$path exists"
        fi
    done
done
