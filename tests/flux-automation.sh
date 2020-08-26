#!/usr/bin/env bash
#set -x

_github_head_sha=$1
_github_base_sha=$2

# Applications in this directories (namespaces) are NOT checked
whitelist_dirs=(
    admin
    kube-system
    kube-public
    knode-system
    monitoring
    neuvector)

# Applications that are currently excluded from this check
exclusions=(
  k8s/aat/common/em/em-showcase.yaml
  k8s/aat/common/idam/idam-api.yaml
  k8s/aat/common/idam/idam-web-admin.yaml
  k8s/aat/common/idam/idam-web-public.yaml
  k8s/prod/common/idam/idam-api.yaml
  k8s/prod/common/idam/idam-web-admin.yaml
  k8s/prod/common/idam/idam-web-public.yaml
)

[ -z "$_github_head_sha" ] && echo "Github head sha missing. Not on a PR" && exit 0
[ -z "$_github_base_sha" ] && echo "Github base sha missing. Not on a PR" && exit 0

_errors=()

git fetch origin master:master

for f in $(git diff-tree --no-commit-id --name-only -r $_github_head_sha $_github_base_sha)
do
  # do not run if file deleted
  [ ! -f "$f" ] && continue
  # run check only if on the prod or aat path
  echo "$f" | grep -E -q "k8s/(aat|prod)/(common|cluster-00|cluster-01)/"
  [ $? -eq 1 ] && continue
  # run check only if not whitelisted
  for wd in "${whitelist_dirs[@]}"
  do
    echo "$f" | grep -E -q "k8s/(aat|prod)/(common|cluster-00|cluster-01)/${wd}"
    [ $? -eq 0 ] && continue 2
  done
  # run check only if not in the exclusions list
  [[ "${exclusions[@]}" =~ "$f" ]] && continue
  # run check only if HelmRelease
  grep -E -q -i 'kind: +helmrelease' "$f"
  [ $? -eq 1 ] && continue

  # check if automated
  grep -E -q '(flux\.weave\.works|fluxcd\.io)/automated: *"true"' "$f"
  [ $? -ne 0 ] && _errors+=("${f}: automated must be set to true")
  # check if prod tag
  grep -E -q '((filter\.)*fluxcd\.io|flux\.weave\.works)/(tag\.)*(java|nodejs|job|function): glob:prod-\*' "$f"
  [ $? -ne 0 ] && _errors+=("${f}: must use a prod-* tag")
done

[ -n "$_errors" ] && printf '%s\n' "${_errors[@]}" > /dev/stderr && exit 2

exit 0
