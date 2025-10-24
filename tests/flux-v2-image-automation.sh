#!/usr/bin/env bash
# set -ex -o pipefail

EXCLUSIONS_LIST=(
    apps/jenkins/jenkins/ptl-intsvc/jenkins.yaml
    apps/jenkins/jenkins/jenkins.yaml
    apps/clamav-mirror/clamav/clamav.yaml
    apps/ccd/ccd-int/ccd-int.yaml.disabled
    apps/docmosis/docmosis/docmosis.yaml
    apps/docmosis/docmosis/aat.yaml
    apps/flux-system/ptl-intsvc/base/gotk-components.yaml
    apps/probate/probate-cron-make-dormant-cases/probate-cron-make-dormant-cases.yaml
    apps/probate/probate-cron-reactivate-dormant-cases/probate-cron-reactivate-dormant-cases.yaml
    apps/probate/*
    apps/monitoring/acr-sync/check-acr-sync.yaml
    apps/private-law/prl-citizen-frontend/aat.yaml
    apps/sscs/sscs-tribunals-frontend/*
    apps/sscs/sscs-tribunals-api/aat.yaml
    apps/sscs/sscs-tya-notif/aat.yaml
    apps/hmc/hmc-operational-reports-runner-int/hmc-operational-reports-runner-int.yaml
    .*perftest.*
    .*sbox.*
    .*test.*
    .*preview.*
    .*staging.*
    .*dev.*
    .*apps/ccd/ccd-data-store-api/aat.yaml.*
    .*demo.*
    .*ithc.*
    .*toffee.*
)

EXCLUSIONS=$(IFS="|" ; echo "${EXCLUSIONS_LIST[*]}")

FILE_LOCATIONS="apps"

for FILE_LOCATION in $(echo ${FILE_LOCATIONS}); do

    ##############################################################################################################
    # This section compiles a list of files that contains `imagepolicy` and stores them in an array IMAGE_POLICIES
    # Only files that follow these rules will be added to the array:
    # - Contains the `imagepolicy` string 
    # - Is NOT in the exclusions list
    # - Is not HelmRelease type document
    ##############################################################################################################
    IMAGE_POLICIES=()
    for FILE in $(grep -lr "imagepolicy" $FILE_LOCATION | grep -Ev "$EXCLUSIONS" ); do

        while read -r doc; do
            if [ "$doc" != "HelmRelease" ]; then
                continue
            fi
        done < <(yq eval '.kind' $FILE)

        IFS=$'\n'
        IMAGE_POLICIES+=($(grep -o "flux-system:.*" $FILE | cut -d ':' -f2 | sed 's/..$//'))

    done

    ##############################################################################################################
    # This section will scan the PTL cluster to find all ImagePolicy configs and add them to temporary yaml files
    # Only scans `clusters/ptl/base` because thats where Image Policies are found, scanning other clusters will
    # result in no output
    ##############################################################################################################
    kustomize build --load-restrictor LoadRestrictionsNone "clusters/ptl-intsvc/base" | yq eval 'select(.metadata and .kind == "ImagePolicy")' -  > imagepolicies_list.yaml
    [ $? -eq 0 ] || (echo "Kustomize build has failed" && exit 1)

    ##############################################################################################################
    # This section loops over each file in the IMAGE_POLICIES array and compares the file with the documents added 
    # to the temporary file imagepolicies_list.yaml
    # If a document is found in the temporary file with the matching name of a policy it is then checked to see
    # if its pattern value matches the specified Prod regex.
    # If this results in a false (i.e. it doesnt match) the script will fail and print the offending Policy name.
    ##############################################################################################################
    for IMAGE_POLICY in "${IMAGE_POLICIES[@]}"; do

        for path in $(echo "clusters/ptl-intsvc/base"); do

            IMAGE_AUTOMATION=$(cat imagepolicies_list.yaml | \
            IMAGE_POLICY_NAME="${IMAGE_POLICY}" yq eval 'select(.kind == "ImagePolicy" and .metadata.name == env(IMAGE_POLICY_NAME) )' -)

            if [ "$IMAGE_AUTOMATION" == "" ]
            then
                echo "No ImagePolicy for $IMAGE_POLICY in clusters/ptl-intsvc/base" && exit 1
            fi

            IMAGE_AUTOMATION_CHECK=$(cat imagepolicies_list.yaml  | \
            IMAGE_POLICY_NAME="${IMAGE_POLICY}" yq eval 'select(.kind == "ImagePolicy" and .metadata.name == env(IMAGE_POLICY_NAME) )' - | yq eval '.spec.filterTags.pattern == "^prod-[a-f0-9]+-(?P<ts>[0-9]+)"' -)

            if [ $IMAGE_AUTOMATION_CHECK == false ]
            then
                echo "Non whitelisted pattern found in ImagePolicy: $IMAGE_POLICY it should be ^prod-[a-f0-9]+-(?P<ts>[0-9]+)" && exit 1
            fi
        done
    done

    ##############################################################################################################
    # Print success if ALL image policies are clean
    ##############################################################################################################
    printf "\n\n########## All Image Policy documents checked and passing ########## \n\n"

    ##############################################################################################################
    # This section will scan the PTL cluster to find all ImagePolicy configs that are kind == ImagePolicy AND 
    # do not contain the override annotation: hmcts.github.com/prod-automated = disabled OR annotations are null
    # add them to temporary yaml file.
    # Only scans `clusters/ptl/base` because thats where Image Policies are found, scanning other clusters will
    # result in no output
    ##############################################################################################################
    kustomize build --load-restrictor LoadRestrictionsNone "clusters/ptl-intsvc/base"  | yq eval 'select(.kind == "ImagePolicy" and ((.metadata.annotations | has("hmcts.github.com/prod-automated") | not) or (.metadata.annotations == null)))' > imagepolicies_defaults_with_patterns.yaml
    [ $? -eq 0 ] || (echo "Kustomize build has failed" && exit 1)

    ##############################################################################################################
    # This section uses the kustomize output to capture names of each document found and stores them in an array 
    # POLICY_NAMES
    # Only files that follow these rules will be added to the array:
    # - is kind == ImagePolicy
    # - has .metadata.name field
    ##############################################################################################################
    POLICY_NAMES=()
    while read -r doc; do
        if [ "$doc" == "---" ]; then
            continue
        fi

        IFS=$'\n'
        POLICY_NAMES+=($doc)
    done < <(yq e '. | select(.kind == "ImagePolicy") | .metadata.name' imagepolicies_defaults_with_patterns.yaml)

    ##############################################################################################################
    # This section uses grep to find all files containing "kind: ImagePolicy" then checks if they also have a
    # filterTags key set. If they do they are added to the array POLICY_FILES
    # Only files that follow these rules will be added to the array:
    # - is kind == ImagePolicy
    # - has .spec.filterTags field
    ##############################################################################################################
    POLICY_FILES=()
    for FILE in $(grep -lr "kind: ImagePolicy" $FILE_LOCATION | grep -Ev "$EXCLUSIONS" ); do
        while read -r doc; do
            if [ "$doc" == true ]; then
                IFS=$'\n'
                POLICY_FILES+=("$FILE")
            fi
        done < <(yq e '(.spec | has("filterTags"))' $FILE)
    done

    ##############################################################################################################
    # This section loops over each POLICY in POLICY_NAMES and then loops over each file in POLICY_FILES
    # For each FILE it checks if the file has a name that matches the POLICY and if so, takes the yaml content and
    # stores this in MATCH variable.
    # If MATCH variable is not empty it then checks the key `.spec.filterTags.pattern` matches the expected 
    # regex `"^prod-[a-f0-9]+-(?P<ts>[0-9]+)"`.
    # If no match log the policy name, file and regex found then exit the script
    ##############################################################################################################

    for POLICY_NAME in "${POLICY_NAMES[@]}"; do
        export POLICY_NAME=$POLICY_NAME
        for FILE in "${POLICY_FILES[@]}"; do
            MATCH=$(yq e 'select(.metadata.name == env(POLICY_NAME))' "$FILE")
            if [ -n "$MATCH" ]; then
                PATTERN=$(echo "$MATCH" | yq e '.spec.filterTags.pattern' -)
                if [[ ! $PATTERN =~ ^prod-[a-f0-9]+-(?P<ts>[0-9]+)$ ]]; then
                    echo "Non whitelisted pattern found in ImagePolicy: $POLICY_NAME located in: $FILE -- it should be ^prod-[a-f0-9]+-(?P<ts>[0-9]+) -- found $PATTERN"
                    exit 1
                fi
            fi
        done
    done

    ##############################################################################################################
    # Print success if ALL image policies are clean
    ##############################################################################################################
    printf "\n\n########## Image Policy documents using defaults checked and passing ########## \n\n"

    ##############################################################################################################
    # This section compiles a list of files that contains `image:` and stores them in an array HELMRELEASES
    # Only files that follow these rules will be added to the array:
    # - Contains the `image:` string 
    # - Is HelmRelease type document
    ##############################################################################################################
    HELMRELEASES=()
    for FILE in $(grep -lr "image:" $FILE_LOCATION | grep -Ev "$EXCLUSIONS" ); do
        while read -r doc; do
            if [ "$doc" == "HelmRelease" ]; then
                IFS=$'\n'
                HELMRELEASES+=("$FILE")
            fi
        done < <(yq eval '.kind' $FILE)
    done

    ##############################################################################################################
    # This section loops over each file in the HELMRELEASES array and checks that it contains an image
    # field that is not null.
    # If not null the image field value is then stripped out and the image Tag value is stored in a variable TAG
    # If that value is not null we then check if the value matches the specificed Prod regex pattern
    # If this results in a false (i.e. it doesnt match) the script will fail and print the offending Policy name.
    ##############################################################################################################

    for RELEASE in "${HELMRELEASES[@]}"; do
    
        IMAGE_TAG_FOUND=$(yq eval 'select(.spec.values.image) or (.spec.values.*.image) != null' $RELEASE)
        
        if [ "$IMAGE_TAG_FOUND" != "" ]
        then
            TAG=$(grep -o "image:.*" $RELEASE | cut -d ':' -f3 | cut -d ' ' -f1  | tr -d \')
            if [ "$TAG" != "" ]
            then
                while read -r doc; do
                    if [ "$doc" == false ]; then
                        echo "!! Non whitelisted pattern found in HelmRelease: $RELEASE it should be prod-[a-f0-9]+-(?P<ts>[0-9]+)" && exit 1
                    fi
                done < <(yq '((.spec.values.image) or (.spec.values.*.image) | test("prod-[a-f0-9]+-(?P<ts>[0-9]+)"))' $RELEASE)
            fi
        fi
    done

    ##############################################################################################################
    # Print success if ALL Helm Release image fields are valid
    ##############################################################################################################
    printf "\n\n ########## Helm Release documents checked and passing ########## \n\n"

done

