# Readme - Patching  28/02/24

## Environments - Non Production

- ITHC
- PERFTEST
- AAT

## Chart Version
Update `./apps/neuvector/neuvector/neuvector.yaml` with the latest chart version and remove the following from each environment file:

- For each non-prod environment remove the references to the custom chart:
```YAML
  chart:
    spec:
      version: 1.5.8
```

## CRDs
To migrate CRD updates from non-prod to prod you must do the following:

- Copy the contents of the `kustomization.yaml` file in this directory and paste them into `./apps/neuvector/crds/kustomization.yaml`
- Remove the following patch from each non-prod cluster base `- path: ../../../apps/neuvector/patching-crds/kustomize.yaml`
    - `./clusters/< env >/base/kustomization.yaml`
    - Environments:
        - ITHC
        - PERFTEST
        - AAT