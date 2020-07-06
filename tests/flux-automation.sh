#!/usr/bin/env bash
set -x

_github_head_sha=$1
_github_base_sha=$2

whitelist_dirs=(
    admin
    kube-system
    kube-public
    knode-system
    monitoring
    neuvector)

[ -z "$_github_head_sha" ] && echo "Error: github head sha missing." && exit 1
[ -z "$_github_base_sha" ] && echo "Error: github base sha missing." && exit 1

_errors=()

git fetch origin master:master

#for f in $(git diff --no-commit-id --name-only origin/master HEAD)
for f in $(git diff-tree --no-commit-id --name-only -r $_github_head_sha $_github_base_sha)
do
  # run check only if on the prod or aat path
  echo "$f" | grep -E -q "k8s/(aat|prod)/(common|cluster-00|cluster-01)/"
  [ $? -eq 1 ] && continue
  # run check only if not whitelisted
  for wd in "${whitelist_dirs[@]}"
  do 
    echo "$f" | grep -E -q "k8s/(aat|prod)/(common|cluster-00|cluster-01)/${wd}"
    [ $? -eq 0 ] && continue 2
  done
  
  # check if automated
  fgrep -E -q '(flux\.weave\.works|fluxcd\.io)/automated: *"true"' "$f"
  [ $? -ne 0 ] && _errors+=("${f}: automated must be set to true")
  # check if prod tag
  fgrep -E -q '(filter\.fluxcd\.io|flux\.weave\.works)/(tag\.)*(java|nodejs): glob:prod-\*' "$f"
  [ $? -ne 0 ] && _errors+=("${f}: must use a prod-* tag")
done  

[ -n "$_errors" ] && printf '%s\n' "${_errors[@]}" > /dev/stderr && exit 2

exit 0
