#!/usr/bin/env bash

set -ex
declare -A SUBMAP

SUBMAP[aat]="DCD-CNP-DEV"
SUBMAP[perftest]="DCD-CNP-QA"
SUBMAP[demo]="DCD-CNP-DEV"
SUBMAP[ithc]="DCD-CNP-QA"
SUBMAP[prod]="DCD-CNP-Prod"
SUBMAP[sbox]="DCD-CFT-Sandbox"

NAMESPACE="$1"
CALLING_NAMESPACE="$2"
ENV="$3"

function usage() {
  echo "usage: ./add-identity-to-env.sh <namespace> <calling-namespace> <env>"
}

if [ -z "${NAMESPACE}" ] || [ -z "${CALLING_NAMESPACE}" ] || [ -z "${ENV}" ]
then
  usage
  exit 1
fi

MI_ENV=${ENV}
if [ "${ENV}"  == "preview" ]
then
    MI_ENV="aat"
fi


IDENTITY_PATH="../../../${CALLING_NAMESPACE}/identity/identity.yaml" yq eval -i '.resources += [env(IDENTITY_PATH)]' apps/${NAMESPACE}/${ENV}/base/kustomization.yaml
IDENTITY_PATH="../../../${CALLING_NAMESPACE}/identity/${MI_ENV}.yaml" yq eval -i '.patchesStrategicMerge += [env(IDENTITY_PATH)]' apps/${NAMESPACE}/${ENV}/base/kustomization.yaml


