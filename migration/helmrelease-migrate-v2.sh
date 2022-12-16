#!/usr/bin/env bash
 set -e

# Example of script ./migration/helmrelease-migrate-v2.sh demo aac
# Run first:
# ./migration/create-namespaces-per-env.sh demo aac
# ./migration/move-namespace-per-env.sh demo aac
# Sample based of https://github.com/hmcts/cnp-flux-config/pull/18863/files
NAMESPACE=$1
ENVIRONMENTS="aat demo perftest ithc prod"

git clean -f apps/ clusters/ k8s/
git checkout apps/ clusters/ k8s/

#Remove comments
  for ENV in $ENVIRONMENTS; do
      yq -i '... comments=""' k8s/$ENV/common-overlay/$NAMESPACE/kustomization.yaml
  done

  for file in $(grep -lr "kind: HelmRelease" k8s/namespaces/$NAMESPACE); do

   APPLICATION=$(echo $file | cut -d '/' -f4)
   FILE_NAME=$(echo $file | cut -d '/' -f5)
   FILE_SHORT_NAME=$(echo $FILE_NAME| cut -d '.' -f1)

   if [ ! -d "apps/$NAMESPACE/$APPLICATION" ]
    then
      mkdir -p apps/$NAMESPACE/$APPLICATION
   fi

   git mv k8s/namespaces/$NAMESPACE/$APPLICATION/$FILE_NAME apps/$NAMESPACE/$APPLICATION/

   if [[ "$ENVIRONMENTS" == *"$FILE_SHORT_NAME"* ]] ; then

     if [[ $(yq '.patchesStrategicMerge[] | select(. == "*'$APPLICATION/$FILE_NAME'*")' k8s/$FILE_SHORT_NAME/common-overlay/$NAMESPACE/kustomization.yaml) ]]; then

         if [[ -z $(yq '.patchesStrategicMerge[] | select(. == "*'$APPLICATION/$FILE_NAME'*")' apps/$NAMESPACE/$FILE_SHORT_NAME/base/kustomization.yaml) ]]; then
               NAMESPACE_PATH="../../$APPLICATION/$FILE_NAME" yq eval -i '.patchesStrategicMerge += [env(NAMESPACE_PATH)]' apps/$NAMESPACE/$FILE_SHORT_NAME/base/kustomization.yaml
         fi
     fi

   elif [[ "$APPLICATION" == *"$FILE_SHORT_NAME"* ]] ; then
     if [[ $(yq '.bases[] | select(. == "*'$APPLICATION'*")' k8s/namespaces/$NAMESPACE/kustomization.yaml) ]]; then

         if [[ -z $(yq '.resources[] | select(. == "*'$APPLICATION'*")' apps/$NAMESPACE/base/kustomization.yaml) ]]; then
             NAMESPACE_PATH="../$APPLICATION/$APPLICATION.yaml" yq eval -i '.resources += [env(NAMESPACE_PATH)]' apps/$NAMESPACE/base/kustomization.yaml
         fi

     fi

    for ENV in $ENVIRONMENTS; do

     if [[ $(yq '.bases[] | select(. == "*'$APPLICATION/$FILE_NAME'*")' k8s/$ENV/common-overlay/$NAMESPACE/kustomization.yaml) ]]; then

         if [[ -z $(yq '.resources[] | select(. == "*'$APPLICATION'*")' apps/$NAMESPACE/$ENV/base/kustomization.yaml) ]]; then
             NAMESPACE_PATH="../../$APPLICATION/$APPLICATION.yaml" yq eval -i '.resources += [env(NAMESPACE_PATH)]' apps/$NAMESPACE/$ENV/base/kustomization.yaml
         fi
    fi
    if [ -d "k8s/$ENV/cluster-00-overlay/$NAMESPACE/" ]; then
      if [[ $(yq '.bases[] | select(. == "*'$APPLICATION/$FILE_NAME'*")' k8s/$ENV/cluster-00-overlay/$NAMESPACE/kustomization.yaml) ]]; then
          if [[ -z $(yq '.resources[] | select(. == "*'$APPLICATION'*")' apps/$NAMESPACE/$ENV/00/kustomization.yaml) ]]; then
                       NAMESPACE_PATH="../../$APPLICATION/$APPLICATION.yaml" yq eval -i '.resources += [env(NAMESPACE_PATH)]' apps/$NAMESPACE/$ENV/00/kustomization.yaml
          fi

      fi
    fi
    if [ -d "k8s/$ENV/cluster-01-overlay/$NAMESPACE/" ]; then
      if [[ $(yq '.bases[] | select(. == "*'$APPLICATION/$FILE_NAME'*")' k8s/$ENV/cluster-01-overlay/$NAMESPACE/kustomization.yaml) ]]; then
          if [[ -z $(yq '.resources[] | select(. == "*'$APPLICATION'*")' apps/$NAMESPACE/$ENV/01/kustomization.yaml) ]]; then
                       NAMESPACE_PATH="../../$APPLICATION/$APPLICATION.yaml" yq eval -i '.resources += [env(NAMESPACE_PATH)]' apps/$NAMESPACE/$ENV/01/kustomization.yaml
          fi

      fi
    fi
    done
   else
     PATCH_ENV=$(echo $FILE_SHORT_NAME | cut -d '-' -f1)
     PATCH_CLUSTER=$(echo $FILE_SHORT_NAME | cut -d '-' -f2)
      if [[ $(yq '.patchesStrategicMerge[] | select(. == "*'$APPLICATION/$FILE_NAME'*")' k8s/$PATCH_ENV/cluster-$PATCH_CLUSTER-overlay/$NAMESPACE/kustomization.yaml) ]]; then

              if [[ -z $(yq '.patchesStrategicMerge[] | select(. == "*'$APPLICATION/$FILE_NAME'*")' apps/$NAMESPACE/$PATCH_ENV/$PATCH_CLUSTER/kustomization.yaml) ]]; then
                    NAMESPACE_PATH="../../$APPLICATION/$FILE_NAME" yq eval -i '.patchesStrategicMerge += [env(NAMESPACE_PATH)]' apps/$NAMESPACE/$PATCH_ENV/$PATCH_CLUSTER/kustomization.yaml
              fi
      fi

   fi
  done


    # Run helmrelease-migrate script
    ./migration/helmrelease-migrate.sh apps/$NAMESPACE/

    for ENV in $ENVIRONMENTS; do
      if [ -d "k8s/$ENV/cluster-00-overlay/$NAMESPACE/" ]; then
          yq 'del( .bases[] | select(. == "'$NAMESPACE'") )' -i k8s/$ENV/cluster-00-overlay/kustomization.yaml
          rm -r k8s/$ENV/cluster-00-overlay/$NAMESPACE
      fi
      if [ -d "k8s/$ENV/cluster-01-overlay/$NAMESPACE/" ]; then
          yq 'del( .bases[] | select(. == "'$NAMESPACE'") )' -i k8s/$ENV/cluster-01-overlay/kustomization.yaml
          rm -r k8s/$ENV/cluster-01-overlay/$NAMESPACE
      fi
      # Remove namespace from environment common-overlay
      yq 'del( .bases[] | select(. == "'$NAMESPACE'") )' -i k8s/$ENV/common-overlay/kustomization.yaml
      # Remove fluxv1 kustomization for environment
      rm -r k8s/$ENV/common-overlay/$NAMESPACE
    done
    rm -r k8s/namespaces/$NAMESPACE