#!/usr/bin/env bash
set -ex

ENV=$1
NAMESPACE=$2

# Example of script ./migration/identity-migration.sh perftest camunda

for file in $(grep -lr "kind: AzureIdentity" k8s/$ENV/common/$NAMESPACE); do
  
   if [ $(echo $file | cut -d'/' -f5) != "identity.yaml" ]
    then
      echo "ignoring $file,please handle it seperately"
       continue
    fi
  
    NAMESPACE=($(yq e '(.metadata.namespace)' $file))

    # Creates directory apps/<namespace>/<environment>
    if [ ! -d "apps/$NAMESPACE/$ENV" ]
    then
        mkdir -p apps/$NAMESPACE/$ENV
    fi

    # Creates directory apps/<namespace>/<environment>/base
    if [ ! -d "apps/$NAMESPACE/$ENV/base" ]
    then
        mkdir -p apps/$NAMESPACE/$ENV/base
    fi

    # Creates file apps/<namespace>/<environment>/base/kustomization.yaml
    if [ ! -f "apps/$NAMESPACE/$ENV/base/kustomization.yaml" ]
    then
(
cat <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../base
EOF
) > "apps/$NAMESPACE/$ENV/base/kustomization.yaml"
fi


  yq eval -i '.resources += "../identity/identity.yaml"' apps/$NAMESPACE/base/kustomization.yaml

  yq eval -i '.patchesStrategicMerge += "../../identity/aat.yaml"' apps/$NAMESPACE/$ENV/base/kustomization.yaml
  
  if [ -d "apps/$NAMESPACE/preview/base" ]
    then
      yq eval -i '.resources += "../../identity/identity.yaml"' apps/$NAMESPACE/preview/base/kustomization.yaml
      yq eval -i '.patchesStrategicMerge +=  ["../../identity/aat.yaml"]' apps/$NAMESPACE/preview/base/kustomization.yaml
  fi


    # Creates directory apps/<namespace>/<environment>/identity/
    if [ ! -d "apps/$NAMESPACE/identity" ]
    then
        mkdir -p apps/$NAMESPACE/identity
    fi
    
    
    # If identity file is not there, then copy to apps/<namespace>/<environment>/sealed-secrets/
    if [ ! -f "apps/$NAMESPACE/identity/identity.yaml" ]
    then
        cp $file apps/$NAMESPACE/identity/
        cp $file /tmp/
        sed -n '/---/q;p' /tmp/identity.yaml > apps/$NAMESPACE/identity/$ENV.yaml
        yq eval 'del(.spec.resourceID) | del(.spec.clientID)' -i apps/$NAMESPACE/identity/identity.yaml
        yq eval 'del(.spec.type)' -i apps/$NAMESPACE/identity/$ENV.yaml
        
    fi
    
done

