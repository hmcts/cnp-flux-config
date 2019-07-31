#!/bin/bash

eval "$(curl -q -s https://raw.githubusercontent.com/coryb/osht/master/osht.sh)"

PLAN 2

prod_check_present=$(grep -c "k8s/prod/ @hmcts/production-apps-approvals" CODEOWNERS)

IS $prod_check_present -eq 1
