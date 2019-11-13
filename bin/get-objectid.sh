#!/usr/bin/env bash

SUB_MAP=( "aat=aat=DCD-CFTAPPS-STG"
  "perftest=perftest=DCD-CFTAPPS-TEST"
  "ithc=ithc=DCD-CFTAPPS-ITHC"
  "sbox=sandbox=DCD-CFTAPPS-SBOX"
  "prod=prod=DCD-CFTAPPS-PROD"
)

SHORT_NAME="$1"

function usage() {
  echo "usage: ./get-objectid.sh <short-name>"
}

if [ -z "${SHORT_NAME}" ]
then
  usage
  exit 1
fi

_len=$(expr ${#SUB_MAP[@]} - 1)

for i in $(seq 0 ${_len})
do
  e=$(echo ${SUB_MAP[${i}]} |cut -d '=' -f 1)
  mi=$(echo ${SUB_MAP[${i}]} |cut -d '=' -f 2)
  sub=$(echo ${SUB_MAP[${i}]} |cut -d '=' -f 3)
  
  OBJECT_ID=$(az identity show --name ${SHORT_NAME}-${mi}-mi --resource-group managed-identities-${e}-rg --subscription ${sub} --query principalId)

  echo "${e}: ${OBJECT_ID}"
done

