# CODEOWNERS guidelines

This repo is multi-tenanted
To enable teams to be self-service, they are allowed to merge changes related to their own applications

The rules are simple:
1. addition of application to environment needs Kustomization changes.
1. Kustomization changes require a review from [@hmcts/platform-operations](https://github.com/orgs/hmcts/teams/platform-operations/members)
1. Teams can add `apps/<namespace>` to CODEOWNERS which allows them to create new files.
1. be sensible, every change is tracked through git, don't repurpose files, create a new one for new applications
