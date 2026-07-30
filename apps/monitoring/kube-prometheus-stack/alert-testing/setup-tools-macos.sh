#!/usr/bin/env bash
set -euo pipefail

echo "==> Checking Homebrew"
if ! command -v brew >/dev/null 2>&1; then
  echo "ERROR: Homebrew not found. Install first:" >&2
  echo "       https://brew.sh" >&2
  exit 1
fi

echo "==> Installing yq"
brew list yq >/dev/null 2>&1 || brew install yq

PROMTOOL_IMAGE="${PROMTOOL_IMAGE:-prom/prometheus:latest}"

echo "==> Installing promtool (preferred: Homebrew package)"
if ! command -v promtool >/dev/null 2>&1; then
  if brew list prometheus >/dev/null 2>&1; then
    :
  elif brew install prometheus >/dev/null 2>&1; then
    :
  else
    echo "WARN: Homebrew prometheus unavailable. Will use containerized promtool." >&2
  fi
fi

echo "==> Verifying binaries"
if ! command -v yq >/dev/null 2>&1; then
  echo "ERROR: yq still not on PATH after install." >&2
  exit 1
fi

if ! command -v promtool >/dev/null 2>&1; then
  if command -v docker >/dev/null 2>&1; then
    docker info >/dev/null 2>&1 || {
      echo "ERROR: docker found but daemon not running. Start Docker Desktop and retry." >&2
      exit 1
    }
    echo "==> Pulling promtool container image: ${PROMTOOL_IMAGE}"
    docker image inspect "${PROMTOOL_IMAGE}" >/dev/null 2>&1 || docker pull "${PROMTOOL_IMAGE}"
  else
    echo "ERROR: promtool not available and docker not found." >&2
    echo "       Install Docker Desktop or install promtool manually." >&2
    exit 1
  fi
fi

echo "==> Versions"
yq --version
if command -v promtool >/dev/null 2>&1; then
  promtool --version
else
  docker run --rm --entrypoint promtool "${PROMTOOL_IMAGE}" --version
fi

echo "==> Done"
echo "Run tests with:"
echo "./test.sh"
