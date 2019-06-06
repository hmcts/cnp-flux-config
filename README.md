# cnp-flux-config
Weave Flux config for AKS clusters

## Creating Sealed Secrets

Install version 0.5.1 from https://github.com/bitnami-labs/sealed-secrets/releases

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

## Bootstrapping sealed secrets for a new cluster

### Adding public cert to the cluster (TODO: automate)
The public cert is used by consumers of the cluster to encrypt secrets

Connect to the cluster you deployed something like:
```
az aks get-credentials --name ithc-00-aks -g ithc-00-rg --subscription DCD-CFTAPPS-ITHC
```

Then run:
```
$ kubectl logs -n admin deployment/sealed-secrets
```

Grab the public cert from the startup logs and place it in:
```
k8s/<env-name>/pub-cert.pem
```

### Flux cloud

Log into sandbox as an admin:
```
$ az aks get-credentials --name sbox-00-aks -g sbox-00-rg --subscription DCD-CFTAPPS-SBOX
```

Retrieve the existing secret (replace `<env>` with your cluster name):
```bash
$ kubectl get secret fluxcloud-values -n admin  -o jsonpath="{['data']['values\.yaml']}" | base64 -D | sed -e 's/sbox-00-aks/<env>-01-aks/' > /tmp/values.yaml
```

Run:
```bash
$ kubectl create secret generic fluxcloud-values --from-file=/tmp/values.yaml --namespace admin --dry-run -o json > /tmp/values.json
$ kubeseal --format=yaml --cert=k8s/<env>/pub-cert.pem < /tmp/values.json > k8s/<env>/cluster-01/fluxcloud/fluxcloud-values.yaml
```

Repeat for cluster01

### Kured values
Log into sandbox as an admin:
```
$ az aks get-credentials --name sbox-00-aks -g sboz-00-rg --subscription DCD-CFTAPPS-SBOX
```

Retrieve the existing secret (replace `<env>` with your cluster name):
```bash
$ kubectl -n kured get secret kured-values  -o jsonpath="{['data']['values\.yaml']}" | base64 -D | sed -e 's/sbox-00-aks/<env>-00-aks/' > /tmp/values.yaml
```

Run:
```bash
$ kubectl create secret generic kured-values --from-file=/tmp/values.yaml --namespace kured --dry-run -o json > /tmp/values.json
$ kubeseal --format=yaml --cert=k8s/<env>/pub-cert.pem < /tmp/values.json > k8s/<env>/cluster-00/kured/kured-values.yaml
```
