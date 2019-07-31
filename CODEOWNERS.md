# CODEOWNERS guidelines

This repo is multi-tenanted
To enable teams to be self service they are allowed to merge changes related to their own applications

The rules are simple:
1. only AAT and prod are protected
1. Prod requires a review from the [@hmcts/production-apps-approvals](https://github.com/orgs/hmcts/teams/production-apps-approvals/members) team
1. AAT requires a review from [@hmcts/platform-engineering](https://github.com/orgs/hmcts/teams/platform-engineering/members) or [@hmcts/devops](https://github.com/orgs/hmcts/teams/devops/members)
1. only file name entries may be added to CODEOWNERS, no directories as that bypasses the review for new applications
1. be sensible, every change is tracked through git, don't repurpose files, create a new one for new applications

To add a new app:

Raise a pull request adding it to `k8s/<env>/common/<product>/<component>.yaml`
If you're adding the application to AAT or prod then then add a line referring to it in CODEOWNERS, i.e. 

```
k8s/aat/common/cmc/claim-store.yaml @hmcts/cmc
k8s/prod/common/cmc/claim-store.yaml @hmcts/cmc
```
