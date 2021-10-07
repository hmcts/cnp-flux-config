# cnp-flux-config
Flux config for AKS clusters

## Repo Structure

This repo is currently being migrated to Flux V2.

Please see [Repo setup](docs/repo-setup.md) for details on how this repo is organized and meant to work.

### Migration status

| Environment  | Instances running | Status |
| ------------- | ------------- | ------------- |
| Prod | Flux V1  | Not Migrated
| AAT |  Flux V1  | Not Migrated
| ITHC | Flux V1  | Not Migrated
| Perftest | Flux V1 & V2  | Migration in progress
| Preview | Flux V2  | Migrated
| Sandbox | Flux V2  | Migrated
| Mgmt (cftptl) | Flux V2  | Migrated
| Mgmt sbox | Flux V2  | Migrated

**Note**: Image automation responsibility for all environments has been moved to Flux v2

## Adding an app to flux

All App deployments are managed through `HelmRelease` manifests. 
Depending on the [Migration Status](#Migration-status), [Image Automation Migration Status](#Image-Automation-Migration-Status) and the environment you are adding your config to , refer [v2 setup](docs/app-deployment-v2.md) or/and [v1 setup](docs/app-deployment.md).

## Creating Sealed Secrets

Install version 0.5.1 from https://github.com/bitnami-labs/sealed-secrets/releases

#### From a Literal
```
kubectl create secret generic my-secret \
  --from-literal key=secret-value \
  --namespace namespace \
  --dry-run=client -o json > my-secret.json

kubeseal --format=yaml --cert=pub-cert.pem < my-secret.json > my-secret.yaml
```
### From a File
```
kubectl create secret generic my-secret \
  --from-file=./some-file.txt \
  --namespace namespace \
  --dry-run=client -o json > my-secret.json

kubeseal --format=yaml --cert=pub-cert.pem < my-secret.json > my-secret.yaml
```

## Bootstrapping sealed secrets for a new cluster

See [new cluster creation](docs/new-cluster.md) steps.

## Upgrading flux v2

Update `flux` cli in your local and run 
 ```bash
flux install --export > apps/flux-system/base/gotk-components.yaml
flux install --export --components image-reflector-controller,image-automation-controller > apps/flux-system/base/image-automation-components.yaml 
```

Currently, `image-automation-components.yaml` will contain some duplication like `namespace` and `clusterrole` and they need to be removed manually