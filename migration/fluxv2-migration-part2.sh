#!/usr/bin/env bash
# set -ex

# Example ./migration/fluxv2-migration-part1.sh perftest dm-store
ENV=$1
NAMESPACE=$2

  echo "Starting Fluxv2 Migration Part 2"
  ./migration/identity-migration-v2.sh $ENV $NAMESPACE
  echo "Deployment Complete for Fluxv2 Migration Part 2 - please create PR, once approved - merge."