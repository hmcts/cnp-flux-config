#!/usr/bin/env bash
set -ex

ENVIRONMENT=$1

#Logging to cft sbox to pull secrets
az aks get-credentials --resource-group cft-sbox-00-rg --name cft-sbox-00-aks --subscription b72ab7b7-723f-4b18-b6f6-03b0f2c6a1bb --overwrite-existing -a

# ----------------------- Cluster files ----------

CLUSTER_DIRECTORY=clusters/$ENVIRONMENT

mkdir -p $CLUSTER_DIRECTORY

mkdir -p $CLUSTER_DIRECTORY/00
mkdir -p $CLUSTER_DIRECTORY/01
mkdir -p $CLUSTER_DIRECTORY/base

cp k8s/$ENVIRONMENT/pub-cert.pem  $CLUSTER_DIRECTORY/pub-cert.pem

(
cat <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- ../../../apps/flux-system/$ENVIRONMENT/base
#- ../../../apps/admin/base/kustomize.yaml
#- ../../../apps/kube-system/base/kustomize.yaml
#- ../../../apps/kured/base/kustomize.yaml
#- ../../../apps/monitoring/base/kustomize.yaml

patches:
- path: ../../../apps/base/kustomize.yaml
  target:
    kind: Kustomization
    annotationSelector: hmcts.github.com/kustomize-defaults != disabled
EOF
) > "$CLUSTER_DIRECTORY/base/kustomization.yaml"
  
  
(
cat <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- ../base

patchesStrategicMerge:
- ../../../apps/flux-system/$ENVIRONMENT/00/kustomize.yaml
EOF
) > "$CLUSTER_DIRECTORY/00/kustomization.yaml"

(
cat <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- ../base

patchesStrategicMerge:
- ../../../apps/flux-system/$ENVIRONMENT/01/kustomize.yaml
EOF
) > "$CLUSTER_DIRECTORY/01/kustomization.yaml"
  
# ----------------------- Flux system files ----------

FLUX_SYSTEM_DIRECTORY=apps/flux-system/$ENVIRONMENT

mkdir -p $FLUX_SYSTEM_DIRECTORY

mkdir -p $FLUX_SYSTEM_DIRECTORY/00
mkdir -p $FLUX_SYSTEM_DIRECTORY/01
mkdir -p $FLUX_SYSTEM_DIRECTORY/base

(
cat <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../base
  - git-credentials.yaml
EOF
) > "$FLUX_SYSTEM_DIRECTORY/base/kustomization.yaml"

(
cat <<EOF
apiVersion: kustomize.toolkit.fluxcd.io/v1beta1
kind: Kustomization
metadata:
  name: flux-system
  namespace: flux-system
spec:
  path: ./$CLUSTER_DIRECTORY/00
  postBuild:
    substitute:
      ENVIRONMENT: "$ENVIRONMENT"
      CLUSTER: "00"
      ENV_MONITOR_CHANNEL: "aks-monitor-$ENVIRONMENT"
      KEYVAULT_ENVIRONMENT: "$ENVIRONMENT"
EOF
) > "$FLUX_SYSTEM_DIRECTORY/00/kustomize.yaml"

(
cat <<EOF
apiVersion: kustomize.toolkit.fluxcd.io/v1beta1
kind: Kustomization
metadata:
  name: flux-system
  namespace: flux-system
spec:
  path: ./$CLUSTER_DIRECTORY/01
  postBuild:
    substitute:
      ENVIRONMENT: "$ENVIRONMENT"
      CLUSTER: "01"
      ENV_MONITOR_CHANNEL: "aks-monitor-$ENVIRONMENT"
      KEYVAULT_ENVIRONMENT: "$ENVIRONMENT"
EOF
) > "$FLUX_SYSTEM_DIRECTORY/01/kustomize.yaml"


kubectl get secrets -n flux-system git-credentials -o yaml > /tmp/git-credentials.yaml
kubeseal --format=yaml --cert=$CLUSTER_DIRECTORY/pub-cert.pem <  /tmp/git-credentials.yaml >  $FLUX_SYSTEM_DIRECTORY/base/git-credentials.yaml

# ----------------------- Admin files ----------

ADMIN_DIRECTORY=apps/admin/$ENVIRONMENT

mkdir -p $ADMIN_DIRECTORY
mkdir -p $ADMIN_DIRECTORY/00
mkdir -p $ADMIN_DIRECTORY/01
mkdir -p $ADMIN_DIRECTORY/base

(
cat <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../base
  - kube-slack-values.yaml
EOF
) > "$ADMIN_DIRECTORY/base/kustomization.yaml"
  
  
(
cat <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../base
EOF
) > "$ADMIN_DIRECTORY/00/kustomization.yaml"

(
cat <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../base
EOF
) > "$ADMIN_DIRECTORY/01/kustomization.yaml"
  
cp k8s/$ENVIRONMENT/common/sealed-secrets/kube-slack-values.yaml  $ADMIN_DIRECTORY/base/kube-slack-values.yaml


# ----------------------- Kured files ----------

KURED_DIRECTORY=apps/kured/$ENVIRONMENT

mkdir -p $KURED_DIRECTORY
mkdir -p $KURED_DIRECTORY/base

(
cat <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../base
  - kured-values.yaml
EOF
) > "$KURED_DIRECTORY/base/kustomization.yaml"
  
cp k8s/$ENVIRONMENT/common/sealed-secrets/kured-values.yaml  $KURED_DIRECTORY/base/kured-values.yaml


# ----------------------- Monitoring files ----------

MONITORING_DIRECTORY=apps/monitoring/$ENVIRONMENT

mkdir -p $MONITORING_DIRECTORY
mkdir -p $MONITORING_DIRECTORY/00
mkdir -p $MONITORING_DIRECTORY/01
mkdir -p $MONITORING_DIRECTORY/base

(
cat <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../base
  - prometheus-values.yaml
EOF
) > "$MONITORING_DIRECTORY/base/kustomization.yaml"
  
(
cat <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../base

patchesStrategicMerge:
  - ../../kube-prometheus-stack/$ENVIRONMENT/00.yaml
EOF
) > "$MONITORING_DIRECTORY/00/kustomization.yaml"

(
cat <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../base

patchesStrategicMerge:
  - ../../kube-prometheus-stack/$ENVIRONMENT/01.yaml
EOF
) > "$MONITORING_DIRECTORY/01/kustomization.yaml"
  
  
cp k8s/$ENVIRONMENT/common/monitoring/monitoring-values.yaml  $MONITORING_DIRECTORY/base/monitoring-values.yaml

echo "Please ensure below steps manually:
1. Review ENV_MONITOR_CHANNEL and KEYVAULT_ENVIRONMENT defined in $FLUX_SYSTEM_DIRECTORY/00/kustomize.yaml and $FLUX_SYSTEM_DIRECTORY/01/kustomize.yaml
2. Ensure correct rbac permissions are added to $ADMIN_DIRECTORY/base/kustomization.yaml"

