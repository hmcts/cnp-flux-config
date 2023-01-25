# cnp-flux-config
Flux v2 config for CFT AKS clusters

## Repo Structure

Please see [Repo setup](docs/repo-setup.md) for details on how this repo is organized and meant to work.

## Adding an app to flux

- All App deployments are managed through `HelmRelease` manifests.
- Any new/existing application that is getting added to an environment for the first time should use [Flux v2](docs/app-deployment-v2.md).

## Creating Sealed Secrets

Install version 0.17.5 from https://github.com/bitnami-labs/sealed-secrets/releases

```
GOOS=$(go env GOOS)
GOARCH=$(go env GOARCH)
wget https://github.com/bitnami/sealed-secrets/releases/download/v0.17.5/kubeseal-0.17.5-$GOOS-$GOARCH.tar.gz -O /tmp/kubeseal.tar.gz
tar -xzvf /tmp/kubeseal.tar.gz
mkdir -p ~/bin
install -m 755 /tmp/kubeseal ~/bin/kubeseal
kubeseal --version
```

#### From a Literal
```
kubectl create secret generic my-secret \
  --from-literal key=secret-value \
  --namespace namespace \
  --dry-run=client -o json > my-secret.json

kubeseal --format=yaml --cert=clusters/<ENV>/pub-cert.pem < my-secret.json > my-secret.yaml
```
### From a File
```
kubectl create secret generic my-secret \
  --from-file=./some-file.txt \
  --namespace namespace \
  --dry-run=client -o json > my-secret.json

kubeseal --format=yaml --cert=clusters/<ENV>/pub-cert.pem < my-secret.json > my-secret.yaml
```

## Bootstrapping sealed secrets for a new cluster

See [new cluster creation](docs/new-cluster.md) steps.

## Upgrading flux v2

Update `flux` cli in your local and run 
 ```bash
flux install --export > apps/flux-system/base/gotk-components.yaml
flux install --export --components image-reflector-controller,image-automation-controller > apps/flux-system/base/image-automation-components.yaml 
```

Currently, `image-automation-components.yaml` will contain some duplication like `namespace` , `clusterrole` and `NetworkPolicy` and they need to be removed manually
