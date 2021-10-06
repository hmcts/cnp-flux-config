#!/usr/bin/env bash
set -ex

# Example of script ./migration/create-v1-roles.sh perftest camunda
ENVIRONMENT=$1
NAMESPACE=$2

(
cat <<EOF

apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: flux-helm-operator
  namespace: $NAMESPACE
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: flux-helm-operator
subjects:
  - name: flux-helm-operator
    namespace: admin
    kind: ServiceAccount

---
EOF
) >> "k8s/namespaces/admin/flux-helm-operator/rbac/$ENVIRONMENT-role-binding.yaml"