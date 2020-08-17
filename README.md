# cnp-flux-config
Flux config for AKS clusters

## Folder Structure


    k8s
    ├── common                                          # Workloads which are not Kustomized and applied across all environments.
    │   └── namespace                                   # One folder per namespace containing workloads.
    │       └── ...
    │       
    ├── namespaces                                     
    │   └── namespace                                   # One folder per namespace containing base resources.
    │       └── ... namespace.yaml                      # Namespace manifest  
    │           ├── kustomization.yaml                  # Kustomization per name space referring all manifests in this directory.
    │           └── <application-name>                  # Folder per app containing manifests and patches for each application.
    │               └── <application-name>.yaml         # Helm Release for each application.
    │               └── <env>.yaml...                   # Optional patch for each environment
    │               └── ...
    │                           
    ├── env(sandbox)
    │   ├── cluster-xx                                  # Folder per cluster containing workloads which aren't overlays / Kustomized but speific to only a particular cluster( not recomnended)
    │   │   ├── namespaces                              # Folder per namespace
    │   │       └── ...
    │   │                                    
    │   ├── (cluster-xx/common)-overlay                 # Kustomized common (or per cluster) folder 
    │   │   ├── .flux.yaml                              # Flux Kustomize file.
    │   │   ├── kustomization.yaml                      # Kustomization referring to below namespaced bases and common env specific overrides.
    │   │   ├── ...
    │   │   └── namespaces                              # Opitonal Folder per namespace
    │   │       └── kustomization.yaml                  # kustomization file referring to team kustomize base and env specific patches.
    │   │
    │   ├── common                                      # Common workloads applied across all clusters in environment.
    │   │   └── namespace                               # Folder per namespace.
    │   │       └── ...
    │   └── pub-cert.pem                                # pem file for sealed-secrets
    └── ...
    
## Adding an app to flux

All App deployments are managed through `HelmRelease` manifests. See [App Deployment section](docs/app-deployment.md) for more details.

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
