#!/usr/bin/env bash
set -ex
FILE_DIRECTORY=$1
NAMESPACE=$2

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
  
  if [[ $FULL_IMAGE == hmctspublic* ]] ;
  then
    REPOSITORY_CREDS="hmctspublic-creds"
  elif [[ $FULL_IMAGE == hmctsprivate* ]] ;
  then
    REPOSITORY_CREDS="hmctsprivate-creds"
  fi
  IMAGE_REPO=$(echo ${FULL_IMAGE} |cut -d ':' -f 1)
  IMAGE_TAG=$(echo ${FULL_IMAGE} |cut -d ':' -f 2)
  
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
) > "${FILE_DIRECTORY}/image-policy.yaml"
    
  else
    
    TAG_PATTERN=${IMAGE_TAG%-*}
    TAG_POLICY_NAME=${TAG_PATTERN}-${HELM_RELEASE_NAME}
(   
cat <<EOF
apiVersion: image.toolkit.fluxcd.io/v1alpha2
kind: ImagePolicy
metadata:
  name: ${TAG_PATTERN}-${HELM_RELEASE_NAME}
spec:
  filterTags:
    pattern: '^${TAG_PATTERN}-[a-f0-9]+-(?P<ts>[0-9]+)'
    extract: '$ts'
  policy:
    alphabetical:
      order: asc
  imageRepositoryRef:
    name: $HELM_RELEASE_NAME
EOF
) > "${FILE_DIRECTORY}/${TAG_PATTERN}-image-policy.yaml"
  
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
) > "${FILE_DIRECTORY}/image-repo.yaml"

IMAGE_PATCH="$FULL_IMAGE #\{\"\$imagepolicy\"\: \"flux-system\:$TAG_POLICY_NAME\"\}"

sed -i '' "s|$FULL_IMAGE|$IMAGE_PATCH|g" $file

#IMAGE_COMMENT=$IMAGE_COMMENT IMAGE_PATH=$IMAGE_PATH yq eval 'env(IMAGE_PATH) lineComment="env(IMAGE_COMMENT)"' -i $file
done
