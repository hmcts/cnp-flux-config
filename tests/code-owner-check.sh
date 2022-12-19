#!/bin/bash

# see https://github.com/coryb/osht for docs
eval "$(curl -q -s https://raw.githubusercontent.com/coryb/osht/master/osht.sh)"

# expected number of tests, (in case any crash occurs)
PLAN 2

kustomization_check_present=$(grep -c "apps/**/kustomization.yaml @hmcts/production-apps-approvals" CODEOWNERS)
kustomize_check_present=$(grep -c "apps/**/kustomize.yaml @hmcts/platform-operations" CODEOWNERS)

IS $prod_check_present -eq 1
IS $kustomize_check_present -eq 1
