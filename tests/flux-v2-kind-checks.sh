# #!/usr/bin/env bash
# set -ex

for file in $(grep -lr "kind: HelmRelease*" apps/money-claims  --exclude-dir=base); do
  
  KIND=$(yq eval '.kind' $file)

  if [ $KIND != "HelmRelease" ]
  then
    echo "kind: should be HelmRelease and not $KIND in file $file." #&& exit 1
    yq e -i '.kind = "HelmRelease"' $file
  fi

done 