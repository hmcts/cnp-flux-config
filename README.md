# cnp-flux-config
Weave Flux config for AKS clusters

## Creating Sealed Secrets
### From a Literal
```
kubectl create secret generic my-secret \
  --from-literal key=secret-value \
  --namespace namespace \
  --dry-run -o json > my-secret.json

kubeseal --format=yaml --cert=pub-cert.pem < my-secret.json > my-secret.yaml
```
### From a File
```
kubectl create secret generic my-secret \
  --from-file=./some-file.txt \
  --namespace namespace \
  --dry-run -o json > my-secret.json

kubeseal --format=yaml --cert=pub-cert.pem < my-secret.json > my-secret.yaml
```