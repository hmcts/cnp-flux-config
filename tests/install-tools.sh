#!/usr/bin/env bash
set -e

VERSION="v4.30.8"
BINARY="yq_linux_amd64"

# get GitHub rate limit
if [ -n "$GITHUB_TOKEN" ]; then
    RATE_LIMIT=$(curl -s -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/rate_limit)
    echo "Authentication successful."
else
    RATE_LIMIT=$(curl -s https://api.github.com/rate_limit)
    echo "No GitHub token provided. Proceeding without authentication."
fi

# get remaining rate limit
REMAINING=$(echo "$RATE_LIMIT" | jq -r '.rate.remaining')

# check if remaining requests are enough
if [ -n "$REMAINING" ] && [ "$REMAINING" -lt 2 ]; then
    echo "Rate limit exceeded. Waiting for a minute..."
    sleep 60
fi

# install yq
wget -q --header="Authorization: token $GITHUB_TOKEN" "https://github.com/mikefarah/yq/releases/download/${VERSION}/${BINARY}.tar.gz" -O - | tar xz
sudo mv ${BINARY} /usr/bin/yq

# install kustomize
curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" -o install_kustomize.sh
chmod +x install_kustomize.sh
rm -rf kustomize
./install_kustomize.sh
