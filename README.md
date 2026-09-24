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

### CCD queue version cutover (CCD-4262)

Deploy data-store migration `V20260923_0000` before starting the queue-based
pipelines. It widens queue IDs and their sequence to bigint, raises the sequence
above 10^10 (or a higher existing sequence/queue ID), and assigns fresh IDs to
queued rows. Raising only the sequence would leave the backlog unsafe.

Before deployment, establish that legacy Elasticsearch versions are below
10^10 in every destination case index and `global_search`. Stop/drain old
Logstash consumers, apply data-store migrations, verify bigint and the backlog
IDs, then deploy/start flux immediately. Do not overlap internal-version and
external-version writers. Search is temporarily stale while consumers are
stopped; writes accumulate in the queue. Check queue drainage and supplementary
data in both relevant destinations after starting consumers.

Monitor output warnings as well as the DLQ: 409s are normally logged and dropped.
Rejecting an older event after a newer success is expected; conflicts with legacy
internal versions require correcting the baseline and requeuing affected cases.
`retry_on_conflict` does not retry these index actions and has been removed.

Coalescing remains enabled. Its unique constraint can make case writes wait for
a poll transaction; the observed 10 ms is not a bound. Validate and monitor write
latency under representative load. Delete-before-delivery remains at-most-once.

For rollback, stop consumers and preserve the queue. Reverting flux alone does
not restore the old marker trigger. Prefer fixing forward; restoring marker
processing requires restoring database behaviour and reconciling cutover writes.
Never rewind the queue sequence. Follow the full data-store release runbook in
`docs/CCD-7841-release.md`, including lock/backlog planning and recovery.

The old marker trigger is dropped by data-store migration `V20240617_4775`,
before the bigint migration, during the stopped-consumer window. This is not a
post-cutover cleanup step. Only removal of the `marked_by_logstash` column is
deferred to CCD-4790 after all consumers have migrated.
