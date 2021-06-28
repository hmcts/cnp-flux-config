#!/usr/bin/env bash
set -ex
FILE_DIRECTORY=$1

for file in $(grep -lr "kind: HelmRelease" $FILE_DIRECTORY); do
  
  yq e '.apiVersion = "helm.toolkit.fluxcd.io/v2beta1"' -i $file
  if $(yq e '.spec | has("valueFileSecrets")' $file) ; then
    SECRETFILE_NAME=$(yq eval '.spec.valueFileSecrets[0].name' $file)
    yq e '.spec.valuesFrom[0].kind="Secret"' -i $file
    SECRETFILE_NAME=$SECRETFILE_NAME yq e '.spec.valuesFrom[0].name = env(SECRETFILE_NAME)' -i $file
    yq eval 'del(.spec.valueFileSecrets)' -i $file
  fi
  yq eval 'del(.spec.rollback)' -i $file
done