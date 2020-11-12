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
### Flux 

ACR credentials for Flux, run below script with ENV ( folder name in flux config) and VAULT_NAME ( name of key vault created during bootstrap)

```bash
#!/usr/bin/env bash
ENV=$1
VAULT_NAME=$2
aks_client_id=$(az keyvault secret show --vault-name $VAULT_NAME --name aks-sp-app-id --query value -o tsv )
aks_client_secret=$(az keyvault secret show --vault-name $VAULT_NAME --name aks-sp-app-password --query value -o tsv )

# -----------------------------------------------------------
(
cat <<EOF
{
  "cloud": "AzurePublicCloud",
  "aadClientId": "$aks_client_id",
  "aadClientSecret": "$aks_client_secret"
}
EOF
) > "/tmp/azure-values.json"
# -----------------------------------------------------------

kubectl create secret generic acr-credentials --from-file=azure.json=/tmp/azure-values.json --namespace admin --dry-run=client -o json > /tmp/azure.json
kubeseal --format=yaml --cert=k8s/$ENV/pub-cert.pem < /tmp/azure.json > k8s/$ENV/common/sealed-secrets/acr-credentials.yaml

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
$ ENV=<your-env>
$ kubectl create secret generic fluxcloud-values --from-file=/tmp/values.yaml --namespace admin --dry-run=client -o json > /tmp/values.json
$ mkdir -p k8s/$ENV/common/sealed-secrets
$ kubeseal --format=yaml --cert=k8s/$ENV/pub-cert.pem < /tmp/values.json > k8s/$ENV/common/sealed-secrets/fluxcloud-values.yaml
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
Update this /tmp/values.yaml file with the Slack WebHook for your environment

Run (replace `<env>` with your env name ):
```bash
$ kubectl create secret generic kured-values --from-file=/tmp/values.yaml --namespace kured --dry-run=client -o json > /tmp/values.json
$ kubeseal --format=yaml --cert=k8s/$ENV/pub-cert.pem < /tmp/values.json > k8s/$ENV/common/sealed-secrets/kured-values.yaml
```

### Neuvector
We install Neuvector on prod like or path-to-live environments

It requires a sealed secret that contains the azure storage account name and key

```bash
$ STORAGE_ACCOUNT_KEY=$(az keyvault secret show --vault-name cftapps-<env> --name storage-account-key --query value -o tsv)

$ kubectl create secret generic nv-storage-secret --from-literal azurestorageaccountkey=${STORAGE_ACCOUNT_KEY} --from-literal azurestorageaccountname=cftapps<env> --namespace neuvector --dry-run=client -o json > /tmp/neuvector.json
$ kubeseal --format=yaml --cert=k8s/<env>/pub-cert.pem < /tmp/neuvector.json > k8s/<env>/common/neuvector/nv-storage-secret.yaml
```

#### Neuvector logging to Log Analytics

We use fluentbit to ship logs to a Log Analytics workspace

It requires a sealed secret that contains the workspace id and key in it

This can only be retrieved from powershell or lots of clicking in the Azure Portal
The "CustomerId" is your workspace ID
```powershell
Connect-AzAccount
Select-AzSubscription DCD-CNP-DEV # prod: DCD-CNP-PROD, sandbox, DCD-CFT-Sandbox
$oms = Get-AzOperationalInsightsWorkspace -ResourceGroupName oms-automation
$workspaceId = $oms.CustomerId.Guid

$keys = Get-AzOperationalInsightsWorkspaceSharedKey -ResourceGroupName oms-automation -Name hmcts-nonprod # prod: hmcts-prod, sandbox: hmcts-sandbox
$primaryKey = $keys.PrimarySharedKey

kubectl create secret generic fluentbit-log --from-literal azure_log_workspace_id=$workspaceId --from-literal azure_log_workspace_shared_key=$primaryKey --namespace neuvector --dry-run=client -o json > /tmp/fluentbit-log.json
```

```bash
kubeseal --format=yaml --cert=k8s/$ENV/pub-cert.pem < /tmp/fluentbit-log.json > k8s/$ENV/common/neuvector/fluentbit-log.yaml
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
  defaultCert: <pbcopy the content of ${SECRET_NAME}.crt file created above>
  defaultKey: <pbcopy the content of ${SECRET_NAME}.key file created above>
```
Create traefik-values sealed secret from the values.yaml 

```bash
kubectl create secret generic traefik-values --namespace=admin --from-file=values.yaml=tmp/values.yaml --dry-run=client -o yaml > tmp/traefiksecret.yaml
mkdir -p k8s/$ENV/common/traefik/
kubeseal --format=yaml --cert=k8s/$ENV/pub-cert.pem <  tmp/traefiksecret.yaml >  k8s/$ENV/common/sealed-secrets/traefik-values.yaml
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
Update this /tmp/values.yaml file with the Slack WebHook for your environment

Run (replace `<env>` with your env name ):
```bash
$ kubectl create secret generic kube-slack-values --from-file=/tmp/values.yaml --namespace admin --dry-run=client -o json > /tmp/values.json
$ kubeseal --format=yaml --cert=k8s/$ENV/pub-cert.pem < /tmp/values.json > k8s/$ENV/common/sealed-secrets/kube-slack-values.yaml
```

### Azure DevOps

Only complete this step for management clusters

```bash
ENV=mgmt-sandbox
AZ_DEVOPS_TOKEN=$(az keyvault secret show --vault-name infra-vault-nonprod --name azure-devops-token --query value -o tsv)
kubectl create secret generic vsts-token --from-literal=token=$AZ_DEVOPS_TOKEN --namespace vsts --dry-run=client -o json > /tmp/values.json
mkdir -p k8s/$ENV/common/vsts/
kubeseal --format=yaml --cert=k8s/$ENV/pub-cert.pem < /tmp/values.json > k8s/$ENV/common/vsts/vsts-token.yaml
```

### External DNS (ideally we'll move this to managed identity)

```bash
ENV=demo
VAULT=cftapps-${ENV}
mkdir -p k8s/$ENV/common/sealed-secrets/
CLIENT_ID=$(az keyvault secret show --vault-name ${VAULT} --name aks-sp-app-id --query value -o tsv)
CLIENT_SECRET=$(az keyvault secret show --vault-name ${VAULT} --name aks-sp-app-password --query value -o tsv)

kubectl create secret generic external-dns --from-literal AZURE_TENANT_ID=531ff96d-0ae9-462a-8d2d-bec7c0b42082 \
  --from-literal AZURE_CLIENT_ID=${CLIENT_ID} --from-literal AZURE_CLIENT_SECRET=${CLIENT_SECRET} \
  --dry-run=client \
  -o json > /tmp/external-dns.json

kubeseal --format=yaml --cert=k8s/$ENV/pub-cert.pem < /tmp/external-dns.json > k8s/$ENV/common/sealed-secrets/external-dns.yaml
```