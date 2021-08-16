#!/usr/bin/env bash
set -ex
FILE_DIRECTORY=$1
NAMESPACE=$2
APPS_DIRECTORY=apps



for file in $(grep -lr "kind: HelmRelease" $FILE_DIRECTORY); do
  
  if [ $(yq eval '.kind' $file) != "HelmRelease" ] 
  then
    continue 
  fi
  
  if [ $(yq eval '.spec.values.image' $file) != null ] 
  then
    IMAGE_PATH=".spec.values.image"
  elif [ $(yq eval '.spec.values.java.image' $file) != null ] 
  then
    IMAGE_PATH=".spec.values.java.image"
  elif [ $(yq eval '.spec.values.nodejs.image' $file) != null ]
  then
    IMAGE_PATH=".spec.values.nodejs.image"
  elif [ $(yq eval '.spec.values.job.image' $file) != null ]
  then
    IMAGE_PATH=".spec.values.job.image"
  elif [ $(yq eval '.spec.values.function.image' $file) != null ]
  then
    IMAGE_PATH=".spec.values.function.image"
  else
    continue 
  fi
  
  FULL_IMAGE=$(yq eval $IMAGE_PATH $file)
  
  HELM_RELEASE_NAME=$(yq eval .metadata.name $file)
  FILE_DIRECTORY=$(dirname $file)
  
  IMAGE_REPO=$(echo ${FULL_IMAGE} |cut -d ':' -f 1)
  IMAGE_TAG=$(echo ${FULL_IMAGE} |cut -d ':' -f 2 | cut -d '-' -f1,2)
 
  mkdir -p ${APPS_DIRECTORY}/${NAMESPACE}/${HELM_RELEASE_NAME}

  if [[ $IMAGE_TAG == prod-* ]] ;
  then
    TAG_POLICY_NAME=${HELM_RELEASE_NAME}
(
cat <<EOF
apiVersion: image.toolkit.fluxcd.io/v1alpha2
kind: ImagePolicy
metadata:
  name: $HELM_RELEASE_NAME
spec:
  imageRepositoryRef:
    name: $HELM_RELEASE_NAME
EOF
) > "${APPS_DIRECTORY}/${NAMESPACE}/${HELM_RELEASE_NAME}/image-policy.yaml"
 
  else
    TAG_POLICY_NAME=${IMAGE_TAG}-${HELM_RELEASE_NAME}
(   
cat <<EOF
apiVersion: image.toolkit.fluxcd.io/v1alpha2
kind: ImagePolicy
metadata:
  name: ${IMAGE_TAG}-${HELM_RELEASE_NAME}
  annotations:
    hmcts.github.com/prod-automated: disabled
spec:
  filterTags:
    pattern: '^${IMAGE_TAG}-[a-f0-9]+-(?P<ts>[0-9]+)'
    extract: '$ts'
  policy:
    alphabetical:
      order: asc
  imageRepositoryRef:
    name: $HELM_RELEASE_NAME
EOF
) > "${APPS_DIRECTORY}/${NAMESPACE}/${HELM_RELEASE_NAME}/${IMAGE_TAG}-image-policy.yaml"
  fi
  
(
cat <<EOF
apiVersion: image.toolkit.fluxcd.io/v1alpha2
kind: ImageRepository
metadata:
  name: $HELM_RELEASE_NAME
spec:
  image: $IMAGE_REPO
EOF
) > "${APPS_DIRECTORY}/${NAMESPACE}/${HELM_RELEASE_NAME}/image-repo.yaml"

if [[ $FULL_IMAGE == hmctsprivate* ]] ;
  then
   yq e '.metadata.annotations."hmcts.github.com/image-registry" = "hmctsprivate"' -i "${FILE_DIRECTORY}/image-repo.yaml"
fi

IMAGE_PATCH="$FULL_IMAGE   #\{\"\$imagepolicy\"\: \"flux-system\:$TAG_POLICY_NAME\"\}"

sed -i '' "s|$FULL_IMAGE|$IMAGE_PATCH|g" $file

done
