#!/bin/bash

# see https://github.com/coryb/osht for docs
eval "$(curl -q -s https://raw.githubusercontent.com/coryb/osht/master/osht.sh)"

# expected number of tests, (in case any crash occurs)
PLAN 2

prod_check_present=$(grep -c "k8s/prod/ @hmcts/production-apps-approvals" CODEOWNERS)
other_prod_check_not_present=$(grep -c "k8s/prod/ .*" CODEOWNERS)

IS $prod_check_present -eq 1
IS $other_prod_check_not_present -eq 1
