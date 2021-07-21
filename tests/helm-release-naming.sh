#!/usr/bin/env bash
set -ex

for file in $(grep -lr "kind: HelmRelease" k8s/namespaces  --exclude-dir={admin,monitoring,neuvector,pact-broker,osba,jenkins,kured}); do
  
  NAMESPACE="$( echo $file | cut -d'/' -f3)"
  FILE_NAMESPACE=$(yq eval .metadata.name k8s/namespaces/$NAMESPACE/namespace.yaml)
  HELM_RELEASE_NAME=$(yq eval .metadata.name $file)
  FILE_DIRECTORY="k8s/namespaces/$NAMESPACE/$HELM_RELEASE_NAME/"
  BASE_MANIFEST="$FILE_DIRECTORY$HELM_RELEASE_NAME.yaml"
  SPEC_RELEASE_NAME=$(yq eval .spec.releaseName $BASE_MANIFEST)
  
  [[ "$HELM_RELEASE_NAME" =~ "ccd-logstash" ]] && continue

  # Make sure spec release name is matching helm release name
  [ "$HELM_RELEASE_NAME" == "$SPEC_RELEASE_NAME" ] || (echo "spec.releaseName not matching HelmRelease name for $HELM_RELEASE_NAME" && exit 1 ) 
  
  # Make sure namespace is matching directory name
  [ "$NAMESPACE" == "$FILE_NAMESPACE" ] || (echo "namespace not matching $NAMESPACE" && exit 1 )
  
  #Make sure file is located in correct directory path
  [[ "$file" =~ $FILE_DIRECTORY.* ]] || (echo "$file with HelmReleaseName $HELM_RELEASE_NAME not in right directory" && exit 1 )
  
  # Check base Manifest exists
  [ -f $BASE_MANIFEST ] || (echo "$HELM_RELEASE_NAME base manifest not found" && exit 1 )
  
  
done
