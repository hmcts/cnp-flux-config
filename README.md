# cnp-flux-config
Flux v2 config for CFT AKS clusters

## Repo Structure

Please see [Repo setup](docs/repo-setup.md) for details on how this repo is organized and meant to work.

## Adding an app to flux

- All App deployments are managed through `HelmRelease` manifests.
- Any new/existing application that is getting added to an environment for the first time should use [Flux v2](docs/app-deployment-v2.md).

## Encrypting Secrets With Sops

 [Sops setup](docs/secrets-sops-encryption.md)

### SOPs

Sops fails linting by default as we require 2 spaces while it uses 4 spaces.
You can use `yq` to fix this:

```
yq eval -I 2 --inplace apps/mi/mi-adf-shir/sbox/mi-adf-auth-values.enc.yaml
```

upstream issue: https://github.com/mozilla/sops/issues/900

## Rebooting nodes with kured

[Documentation](docs/reboot-node-using-kured.md)

## Upgrading flux v2

Update `flux` cli in your local and run 
 ```bash
flux install --export > apps/flux-system/base/gotk-components.yaml
flux install --export --components source-controller,kustomize-controller,helm-controller,notification-controller,image-reflector-controller,image-automation-controller > apps/flux-system/ptl-intsvc/base/gotk-components.yaml 
```

As Flux in PTL makes use of optional GOTK image automation components, we generate a second `gotk-components.yaml` file just for PTL. Information about Flux GOTK components can be found [here](https://fluxcd.io/flux/components/). 

Both files are maintained by Renovate after generation.
 
## Logstash queue processing

CCD Logstash agents use a bounded plain-delete queue poll. A selected queue
row is deleted before its Elasticsearch write, so delivery is at-most-once.
Recover an Elasticsearch or pod failure by inserting only the affected case
IDs back into `case_data_logstash_queue`; do not reset `marked_by_logstash` or
configure a claim timeout. See the CCD-4262 queue-processing runbook in
`ccd-data-store-api` for the recovery query and release evidence required.
