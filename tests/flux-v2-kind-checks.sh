# #!/usr/bin/env bash
# set -ex

# for file in $(grep -lr "kind: HelmRelease*" apps/money-claims  --exclude-dir=base); do

for file in $(grep -lr "kind: HelmRelease*" apps/money-claims/cmc-legal-frontend); do
  KIND=()
  KIND=$(yq eval '.kind' $file)

    echo "KIND on file: $file is $KIND"
  if [ $KIND != "HelmRelease" ]
  then
    echo "kind: should be HelmRelease and not $KIND in file $file."
    yq e -i '.kind = "HelmRelease"' $file
  fi

done 