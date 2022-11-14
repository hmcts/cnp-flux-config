#!/usr/bin/env bash
# set -ex

# Example ./migration/fluxv2-migration-part2.sh perftest dm-store
ENV=$1
NAMESPACE=$2

  echo "Starting Fluxv2 Migration Part 2"
  ./migration/helmrelease-migrate-v2.sh $ENV $NAMESPACE || error_exit "ERROR: Unable to complete helm migration."
  echo "Deployment Complete for Fluxv2 Migration Part 2 - please create PR, once approved - merge."