#!/usr/bin/env bash
set -ex
FILE_DIRECTORY=$1
mkdir -p $FILE_DIRECTORY/automation

(
cat <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
EOF
) > "$FILE_DIRECTORY/automation/kustomization.yaml"

for file in $(grep -lr "kind: ImagePolicy\|kind: ImageRepository" $FILE_DIRECTORY); do
  
  if [[ $(yq eval '.kind' $file) == "ImagePolicy" ]] || [[ $(yq eval '.kind' $file) == "ImageRepository" ]]
  then
  FILE_PATH=$(realpath --relative-to=$FILE_DIRECTORY/automation $file)
  FILE_PATH=$FILE_PATH  yq eval '.resources += [env(FILE_PATH)]' -i $FILE_DIRECTORY/automation/kustomization.yaml
  fi
  
done
