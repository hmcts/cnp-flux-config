#!/usr/bin/env bash
set -e

VERSION=v4.30.8
BINARY=yq_linux_amd64
MAX_RETRIES=1
WAIT_TIME=30  

# Function to download and install yq
install_yq() {
    echo "Downloading yq..."
    wget --header="Authorization: token $AUTH_TOKEN" "https://github.com/mikefarah/yq/releases/download/${VERSION}/${BINARY}.tar.gz" -O - | tar xz
    sudo mv ${BINARY} /usr/bin/yq
}

# Function to download and install kustomize
install_kustomize() {
    echo "Downloading kustomize..."
    curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" -o install_kustomize.sh
    chmod +x install_kustomize.sh
    ./install_kustomize.sh
}

# Function to check GitHub rate limit
check_rate_limit() {
    if [ -n "$AUTH_TOKEN" ]; then
        RATE_LIMIT=$(curl -s -H "Authorization: token $AUTH_TOKEN" https://api.github.com/rate_limit)
    else
        RATE_LIMIT=$(curl -s https://api.github.com/rate_limit)
    fi

    # Extract remaining rate limit
    REMAINING=$(echo "$RATE_LIMIT" | jq -r '.resources.code_scanning_upload.remaining')
    echo "Remaining rate limit: $REMAINING"  # Debug output

    # Check if remaining requests are enough
    if [$((REMAINING)) -lt 2 ]; then
        echo "Rate limit exceeded. Waiting for $WAIT_TIME seconds..."
        sleep $WAIT_TIME
    fi
}

# Retry downloading yq if rate limit is still exceeded
for ((i=0; i<=MAX_RETRIES; i++)); do
    check_rate_limit
    install_yq && break
    echo "yq download failed. Retrying in $WAIT_TIME seconds..."
    sleep $WAIT_TIME
done

# Retry downloading kustomize if rate limit is still exceeded
for ((i=0; i<=MAX_RETRIES; i++)); do
    check_rate_limit
    install_kustomize && break
    echo "kustomize download failed. Retrying in $WAIT_TIME seconds..."
    sleep $WAIT_TIME
done
