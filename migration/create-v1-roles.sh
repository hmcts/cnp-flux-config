#!/usr/bin/env bash
set -ex

ENVIRONMENT=$1

for namespace in $(kubectl get hr -A -o jsonpath={.items[*].metadata.namespace} | xargs -n1 | sort -u | xargs); do
(
cat <<EOF

apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: helm-operator
  namespace: $namespace
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: helm-operator
subjects:
  - name: helm-operator
    namespace: flux
    kind: ServiceAccount

---
EOF
) >> "k8s/namespaces/admin/flux-helm-operator/rbac/$ENVIRONMENT-role-binding.yaml"
done