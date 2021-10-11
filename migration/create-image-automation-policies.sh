#!/usr/bin/env bash
set -ex
# Example of Script ./migration/create-image-automation-policies.sh k8s/namespaces/bsp bsp
FILE_DIRECTORY=$1
NAMESPACE=$2
APPS_DIRECTORY=apps

if [ -z "$NAMESPACE" ]; then
  echo "Error: Missing NAMESPACE, example of script: ./migration/create-image-automation-policies.sh k8s/namespaces/bsp bsp"
  exit 1
fi

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

  if [[ ${file} == k8s/namespaces* ]] ;
  then
    ENV_NAME=$(echo ${file} | sed 's|.*/||'  | cut -d '.' -f1)
  else
    ENV_NAME=$(echo ${file} | cut -d '/' -f2)
  fi

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
    TAG_POLICY_NAME=${ENV_NAME}-${HELM_RELEASE_NAME}
(   
cat <<EOF
apiVersion: image.toolkit.fluxcd.io/v1alpha2
kind: ImagePolicy
metadata:
  name: ${ENV_NAME}-${HELM_RELEASE_NAME}
  annotations:
    hmcts.github.com/prod-automated: disabled
spec:
  filterTags:
    pattern: '^${IMAGE_TAG}-[a-f0-9]+-(?P<ts>[0-9]+)'
    extract: '\$ts'
  policy:
    alphabetical:
      order: asc
  imageRepositoryRef:
    name: $HELM_RELEASE_NAME
EOF
) > "${APPS_DIRECTORY}/${NAMESPACE}/${HELM_RELEASE_NAME}/${ENV_NAME}-image-policy.yaml"
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
   yq e '.metadata.annotations."hmcts.github.com/image-registry" = "hmctsprivate"' -i "${APPS_DIRECTORY}/${NAMESPACE}/${HELM_RELEASE_NAME}/image-repo.yaml"
fi

IMAGE_PATCH="$FULL_IMAGE   #\{\"\$imagepolicy\"\: \"flux-system\:$TAG_POLICY_NAME\"\}"

sed -i '' "s|$FULL_IMAGE|$IMAGE_PATCH|g" $file


###########
# Added additional to capture smoketests.images etc - 3 are commented as smoketests.image is used with all 4
# as below. Using sed, if all 4 are used, it will show x4

  IMAGE_PATH_ADDITIONAL=()
  if [ $(yq eval '.spec.values.java.smoketests.image' $file) != null ] 
  then
    IMAGE_PATH_ADDITIONAL+=(".spec.values.java.smoketests.image")
  fi

  # if [ $(yq eval '.spec.values.java.functionaltests.image' $file) != null ] 
  # then
  #   IMAGE_PATH_ADDITIONAL+=(".spec.values.java.functionaltests.image")
  # fi

  # if [ $(yq eval '.spec.values.java.smoketestscron.image' $file) != null ] 
  # then
  #   IMAGE_PATH_ADDITIONAL+=(".spec.values.java.smoketests.image")
  # fi

  # if [ $(yq eval '.spec.values.java.functionaltestscron.image' $file) != null ] 
  # then
  #   IMAGE_PATH_ADDITIONAL+=(".spec.values.java.functionaltests.image")
  # fi

  for IMAGE_PATH_ADDITIONAL in ${IMAGE_PATH_ADDITIONAL[@]}; do

  FULL_IMAGE=$(yq eval $IMAGE_PATH_ADDITIONAL $file)
  HELM_RELEASE_NAME=$(yq eval .metadata.name $file)
  FILE_DIRECTORY=$(dirname $file)
  
  IMAGE_REPO=$(echo ${FULL_IMAGE} |cut -d ':' -f 1)
  IMAGE_TAG=$(echo ${FULL_IMAGE} |cut -d ':' -f 2 | cut -d '-' -f1,2)

  if [[ ${file} == k8s/namespaces* ]] ;
  then
    ENV_NAME=$(echo ${file} | sed 's|.*/||'  | cut -d '.' -f1)
  else
    ENV_NAME=$(echo ${file} | cut -d '/' -f2)
  fi

  TAG_POLICY=$(yq eval $IMAGE_PATH_ADDITIONAL $file | sed 's|.*/||'  | cut -d ':' -f1)

    if [[ $IMAGE_TAG == prod-* ]] ;
  then
    TAG_POLICY_NAME=${TAG_POLICY}
(
cat <<EOF
apiVersion: image.toolkit.fluxcd.io/v1alpha2
kind: ImagePolicy
metadata:
  name: ${HELM_RELEASE_NAME}-${TAG_POLICY}
spec:
  imageRepositoryRef:
    name: ${HELM_RELEASE_NAME}-${TAG_POLICY_NAME}
EOF
) > "${APPS_DIRECTORY}/${NAMESPACE}/${HELM_RELEASE_NAME}/${TAG_POLICY_NAME}-image-policy.yaml"
 
  else
    TAG_POLICY_NAME=${ENV_NAME}-${HELM_RELEASE_NAME}
(   
cat <<EOF
apiVersion: image.toolkit.fluxcd.io/v1alpha2
kind: ImagePolicy
metadata:
  name: ${ENV_NAME}-${HELM_RELEASE_NAME}-${TAG_POLICY_NAME}
  annotations:
    hmcts.github.com/prod-automated: disabled
spec:
  filterTags:
    pattern: '^${IMAGE_TAG}-[a-f0-9]+-(?P<ts>[0-9]+)'
    extract: '\$ts'
  policy:
    alphabetical:
      order: asc
  imageRepositoryRef:
    name: ${HELM_RELEASE_NAME}-${TAG_POLICY_NAME}
EOF
) > "${APPS_DIRECTORY}/${NAMESPACE}/${HELM_RELEASE_NAME}/${ENV_NAME}-${TAG_POLICY_NAME}-image-policy.yaml"
  fi
  
(
cat <<EOF
apiVersion: image.toolkit.fluxcd.io/v1alpha2
kind: ImageRepository
metadata:
  name: ${HELM_RELEASE_NAME}-${TAG_POLICY_NAME}
spec:
  image: $IMAGE_REPO
EOF
) > "${APPS_DIRECTORY}/${NAMESPACE}/${HELM_RELEASE_NAME}/${TAG_POLICY_NAME}-image-repo.yaml"

if [[ $FULL_IMAGE == hmctsprivate* ]] ;
  then
   yq e '.metadata.annotations."hmcts.github.com/image-registry" = "hmctsprivate"' -i "${APPS_DIRECTORY}/${NAMESPACE}/${HELM_RELEASE_NAME}/image-repo.yaml"
fi

IMAGE_PATCH="$FULL_IMAGE   #\{\"\$imagepolicy\"\: \"flux-system\:$TAG_POLICY_NAME\"\}"

sed -i '' "s|$FULL_IMAGE|$IMAGE_PATCH|g" $file

  done

done