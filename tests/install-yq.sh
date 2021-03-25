#!/usr/bin/env bash

set -e

VERSION=v4.6.1
BINARY=yq_linux_amd64
wget https://github.com/mikefarah/yq/releases/download/${VERSION}/${BINARY}.tar.gz -O - | \
  tar xz && sudo mv ${BINARY} /usr/bin/yq