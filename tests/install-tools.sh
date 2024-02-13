#!/usr/bin/env bash
set -e

VERSION=v4.30.8
BINARY=yq_linux_amd64

# Download yq using the provided GitHub token
wget_output=$(wget -q --header="Authorization: token $GITHUB_TOKEN" "https://github.com/mikefarah/yq/releases/download/${VERSION}/${BINARY}.tar.gz" -O -)
echo "Downloaded file: $wget_output"

# Check if the download was successful
if [ $? -eq 0 ]; then
    echo "Authentication successful. Downloaded yq."
else
    echo "Error: Authentication failed or download unsuccessful."
    exit 1
fi

# Extract yq binary
echo "Extracting yq binary..."
echo "$wget_output" | tar tz
echo "$wget_output" | tar xz

# Check if the downloaded file contains the expected binary
if echo "$wget_output" | tar tz | grep -q "$BINARY"; then
    echo "Found $BINARY in the downloaded tarball."
else
    echo "Error: $BINARY not found in the downloaded tarball."
    exit 1
fi

# Move yq binary to /usr/bin
echo "Moving yq binary to /usr/bin..."
echo "$wget_output" | tar xz && sudo mv ${BINARY} /usr/bin/yq

# Install kustomize
echo "Installing kustomize..."
curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" -o install_kustomize.sh
chmod +x install_kustomize.sh
rm -rf kustomize
./install_kustomize.sh

echo "yq and kustomize installation completed successfully."
