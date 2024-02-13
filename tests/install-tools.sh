#!/usr/bin/env bash
set -ex

VERSION=v4.30.8
BINARY=yq_linux_amd64

# Download yq using the provided GitHub token
wget -q --header="Authorization: token $GITHUB_TOKEN" "https://github.com/mikefarah/yq/releases/download/${VERSION}/${BINARY}.tar.gz" -O - \
  tar xz && sudo mv ${BINARY} /usr/bin/yq
# Check if the download was successful
if [ $? -eq 0 ]; then
    echo "Authentication successful. Downloaded yq."
else
    echo "Error: Authentication failed or download unsuccessful."
    exit 1
fi

# Install kustomize
curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" -o install_kustomize.sh
chmod +x install_kustomize.sh
rm -rf kustomize
./install_kustomize.sh
