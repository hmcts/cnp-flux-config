#!/usr/bin/env bash
set -e

VERSION=v4.26.1
BINARY=yq_linux_amd64
wget https://github.com/mikefarah/yq/releases/download/${VERSION}/${BINARY}.tar.gz -O - | \
  tar xz && sudo mv ${BINARY} /usr/bin/yq

curl -s "https://raw.githubusercontent.com/\
kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" -o install_kustomize.sh && chmod +x install_kustomize.sh && rm -rf kustomize && ./install_kustomize.sh 3.7.0