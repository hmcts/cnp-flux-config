# cnp-flux-config
Weave Flux config for AKS clusters

## Folder Structure


    k8s
    ├── common                                          # Workloads which are not Kustomized and applied across all environments.
    │   └── ...                                         # One folder per namespace containing workloads.
    │       └── namespace.yaml
    ├── common-base                                     # Kustomization base for common workloads applied across all environments. Used for Admin workloads.
    │   ├── namespace
    │   │   └── ...                                     # One folder per namespace containing base resources.
    │   │       ├── kustomization.yaml                  # Kustomization per name space to be able to override them individually 
    │   │       └── ...                                 # Resources
    │   └── kustomization.yaml                          # Kustomize file for common-base referring to nested directories
    ├── env(sandbox)                                     
    │   ├── cluster-xx                                  # Folder per cluster
    │   │   ├── static                                  # Directory containing workloads which aren't overlays / Kustomized.
    │   │   │   └── ...                                 # Folder per namespace.
    │   │   │       └── ...
    │   │   └── static-overlay                          # Directory containing Kustomized workloads not having image automation.
    │   │       └── .flux.yaml                          # Flux Kustomize file.
    │   │       └── static
    │   │           ├── kustomization.yaml              # kustomization file referring to env base and overrides. 
    │   │           └── ...                             # Folder per namespace containing patch workloads.
    │   │               └── ...
    │   │
    │   ├── common                                      # Common workloads applied across all clusters in environment.
    │   │   └── ...                                     # Folder per namespace containing common workloads.
    │   │       └── ...
    │   ├── env-base                                    # Kustomization directory overlaying common-base.                                
    │   │   ├── ...                                     # Folder per namespace containing overriding patches / additional resources on top of basic resources.
    │   │   │   └── ...
    │   │   └── kustomization.yaml                      
    │   └── pub-cert.pem                                # pem file for sealed-secrets
    └── ...
    


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
az aks get-credentials --name <env>-00-aks -g <env>-00-rg --subscription DCD-CFTAPPS-<env>
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

Retrieve the existing secret :
```bash
$ kubectl get secret fluxcloud-values -n admin  -o jsonpath="{['data']['values\.yaml']}" | base64 -D > /tmp/values.yaml
```
You have a slack channel with name aks-monitor-<env>.

Run (replace `<env>` with your env name ):
```bash
$ kubectl create secret generic fluxcloud-values --from-file=/tmp/values.yaml --namespace admin --dry-run -o json > /tmp/values.json
$ kubeseal --format=yaml --cert=k8s/<env>/pub-cert.pem < /tmp/values.json > k8s/<env>/common/sealed-secrets/fluxcloud-values.yaml
```

### Kured values
Log into sandbox as an admin:
```
$ az aks get-credentials --name sbox-00-aks -g sbox-00-rg --subscription DCD-CFTAPPS-SBOX --overwrite-existing
```

Retrieve the existing secret:
```bash
$ kubectl -n kured get secret kured-values  -o jsonpath="{['data']['values\.yaml']}" | base64 -D > /tmp/values.yaml
```

Run (replace `<env>` with your env name ):
```bash
$ kubectl create secret generic kured-values --from-file=/tmp/values.yaml --namespace kured --dry-run -o json > /tmp/values.json
$ kubeseal --format=yaml --cert=k8s/<env>/pub-cert.pem < /tmp/values.json > k8s/<env>/common/sealed-secrets/kured-values.yaml
```

### Neuvector
We install Neuvector on prod like or path-to-live environments

It requires a sealed secret that contains the azure storage account name and key

```bash
$ STORAGE_ACCOUNT_KEY=$(az keyvault secret show --vault-name cftapps-<env> --name storage-account-key --query value -o tsv)

$ kubectl create secret generic storage-secret --from-literal azurestorageaccountkey=${STORAGE_ACCOUNT_KEY} --from-literal azurestorageaccountname=cftapps<env> --namespace neuvector --dry-run -o json > /tmp/neuvector.json
$ kubeseal --format=yaml --cert=k8s/<env>/pub-cert.pem < /tmp/neuvector.json > k8s/<env>/common/neuvector/nv-storage-secret.yaml
```

#### Neuvector logging to Log Analytics

We use fluentbit to ship logs to a Log Analytics workspace

It requires a sealed secret that contains the workspace id and key in it

This can only be retrieved from powershell or lots of clicking in the Azure Portal
The "CustomerId" is your workspace ID
```powershell
Connect-AzAccount
Select-AzSubscription  DCD-CFTAPPS-<env>
$oms = Get-AzOperationalInsightsWorkspace
$workspaceId = $oms.CustomerId.Guid

$keys = Get-AzOperationalInsightsWorkspaceSharedKey -ResourceGroupName oms-automation-rg -Name hmcts-<env>-law
$primaryKey = $keys.PrimarySharedKey

kubectl create secret generic fluentbit-log --from-literal azure_log_workspace_id=$workspaceId --from-literal azure_log_workspace_shared_key=$primaryKey --namespace neuvector --dry-run -o json > /tmp/fluentbit-log.json
```

```bash
kubeseal --format=yaml --cert=k8s/<env>/pub-cert.pem < /tmp/fluentbit-log.json > k8s/<env>/common/neuvector/fluentbit-log.yaml
```

### Traefik

In case you are enforcing ssl on Traefik( Refer Demo for flux config) with an existing pfx in keyvault, extract the certificate and key using below: 

```bash
mkdir tmp
cd tmp
KEY_VAULT=${1} # infra-vault-sandbox
SECRET_NAME=${2} #STAR-sandbox-platform-hmcts-net

az keyvault secret show --vault-name ${KEY_VAULT} --name ${SECRET_NAME} --query value -o tsv | base64 -D > ${SECRET_NAME}.pfx
openssl pkcs12 -in ${SECRET_NAME}.pfx -nokeys -nodes -passin pass:"" | base64 > ${SECRET_NAME}.crt
openssl pkcs12 -in ${SECRET_NAME}.pfx -nocerts -nodes -passin pass:"" | base64 > ${SECRET_NAME}.key

```

Create a values.yaml file like below in tmp directory
```yaml
ssl:
  defaultCert: <pbcopy the content of ${SECRET_NAME}.crt file created above"
  defaultKey: <pbcopy the content of ${SECRET_NAME}.key file created above"
```
Create traefik-values sealed secret from the values.yaml 

```bash
kubectl create secret generic traefik-values --namespace=admin --from-file=values.yaml=tmp/values.yaml --dry-run -o yaml > tmp/traefiksecret.yaml
kubeseal --format=yaml --cert=k8s/mgmt-sandbox/pub-cert.pem <  tmp/traefiksecret.yaml >  k8s/<env>/common/traefik/traefik-values.yaml
```

### Kube-Slack
To add Kube-Slack for Slack monitoring on AKS cluster, change the SLACK_CHANNEL in HelmRelease to env specific slack channel.

Log into sandbox as an admin:
```
$ az aks get-credentials --name sbox-00-aks -g sbox-00-rg --subscription DCD-CFTAPPS-SBOX --overwrite-existing
```

Retrieve the existing secret:
```bash
$ kubectl -n admin get secret kube-slack-values  -o jsonpath="{['data']['values\.yaml']}" | base64 -D > /tmp/values.yaml
```

Run (replace `<env>` with your env name ):
```bash
$ kubectl create secret generic kube-slack-values --from-file=/tmp/values.yaml --namespace admin --dry-run -o json > /tmp/values.json
$ kubeseal --format=yaml --cert=k8s/<env>/pub-cert.pem < /tmp/values.json > k8s/<env>/common/sealed-secrets/kube-slack-values.yaml
```
