#!/usr/bin/env bash
set -ex
FILE_DIRECTORY=$1

# Example of script ./migration/helmrelease-migrate.sh k8s/namespaces/camunda

for file in $(grep -lr "kind: HelmRelease" $FILE_DIRECTORY); do
  
  yq e '.apiVersion = "helm.toolkit.fluxcd.io/v2beta1"' -i $file
  if $(yq e '.spec | has("valueFileSecrets")' $file) ; then
    SECRETFILE_NAME=$(yq eval '.spec.valueFileSecrets[0].name' $file)
    yq e '.spec.valuesFrom[0].kind="Secret"' -i $file
    SECRETFILE_NAME=$SECRETFILE_NAME yq e '.spec.valuesFrom[0].name = env(SECRETFILE_NAME)' -i $file
    yq eval 'del(.spec.valueFileSecrets)' -i $file
  fi
  yq eval 'del(.spec.rollback)' -i $file
  yq eval 'del(.metadata.annotations)' -i $file
  if $(yq e '.spec | has("chart")' $file) ; then
    
    if $(yq e '.spec.chart | has("repository")' $file) ; then
      CHART_REPO=$(yq eval '.spec.chart.repository' $file)
      CHART_NAME=$(yq eval '.spec.chart.name' $file)
      CHART_VERSION=$(yq eval '.spec.chart.version' $file)
    
      yq eval 'del(.spec.chart)' -i $file
      CHART_NAME=$CHART_NAME CHART_VERSION=$CHART_VERSION yq e '.spec.chart.spec.chart = env(CHART_NAME)|.spec.chart.spec.version = env(CHART_VERSION) ' -i $file
        if [[ $CHART_REPO == *"hmctspublic"* ]]; then
         yq e '.spec.chart.spec.sourceRef.kind = "HelmRepository"|.spec.chart.spec.sourceRef.name = "hmctspublic"| .spec.chart.spec.sourceRef.namespace = "flux-system"' -i $file
        fi
    elif $(yq e '.spec.chart | has("git")' $file) ; then
    
      CHART_GIT=$(yq eval '.spec.chart.git' $file)
      CHART_REF=$(yq eval '.spec.chart.ref' $file)
      CHART_PATH=$(yq eval '.spec.chart.path' $file)
    
      yq eval 'del(.spec.chart)' -i $file
      NEW_CHART_PATH="./${CHART_PATH}"
      NEW_CHART_PATH=$NEW_CHART_PATH yq e '.spec.chart.spec.chart = env(NEW_CHART_PATH)' -i $file
      if [[ $CHART_GIT == *"hmcts/hmcts-charts"* ]]; then
       yq e '.spec.chart.spec.sourceRef.kind = "GitRepository"|.spec.chart.spec.sourceRef.name = "hmcts-charts"| .spec.chart.spec.sourceRef.namespace = "flux-system" | .spec.chart.spec.interval = "1m"' -i $file
      fi
    fi
  fi
done