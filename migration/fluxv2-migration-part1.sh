#!/usr/bin/env bash
# set -ex

# Example ./migration/fluxv2-migration-part1.sh perftest dm-store
ENV=$1
NAMESPACE=$2

  echo "Starting Fluxv2 Migration Part 1"
  ./migration/identity-migration-v2.sh $ENV $NAMESPACE || error_exit "ERROR: Unable to complete identity migration."
  ./migration/create-namespaces-per-env.sh $ENV $NAMESPACE || error_exit "ERROR: Unable to complete namespace creation."
  ./migration/move-namespace-per-env.sh $ENV $NAMESPACE || error_exit "ERROR: Unable to move namespace."
  echo "Deployment Complete for Fluxv2 Migration Part 1 - please create PR, once approved and merged, run Fluxv2 Migration Part 2"