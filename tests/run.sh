#!/bin/bash

# see https://github.com/coryb/osht for docs
eval "$(curl -q -s https://raw.githubusercontent.com/coryb/osht/master/osht.sh)"

# expected number of tests, (in case any crash occurs)
PLAN 1

prod_check_present=$(grep -c "k8s/prod/ @hmcts/production-apps-approvals" CODEOWNERS)

IS $prod_check_present -eq 1
