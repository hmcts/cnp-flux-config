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
clusters/<env-name>/pub-cert.pem
```
### Flux 

Git access for Flux is managed through a couple of deploy keys added to repo.

1. `flux-write` with write access to repo , used only by cftptl to commit image automation.
2. `flux-read` with read-only access to repo, unsed by all other environments.

Log into existing environment (sandbox) as an admin:
```
$ az aks get-credentials --resource-group cft-sbox-00-rg --name cft-sbox-00-aks --subscription b72ab7b7-723f-4b18-b6f6-03b0f2c6a1bb --overwrite-existing -a && kubectl config use-context cft-sbox-00-aks-admin
```
and run
```
ENV=<test>
kubectl get secrets -n flux-system git-credentials -o yaml > /tmp/git-credentials.yaml
mkdir -p apps/flux-system/$ENV
mkdir -p apps/flux-system/$ENV/base
kubeseal --format=yaml --cert=clusters/$ENV/pub-cert.pem <  /tmp/git-credentials.yaml >  apps/flux-system/$ENV/base/git-credentials.yaml
```

### Kured values
Log into sandbox as an admin:
```
$ az aks get-credentials --resource-group cft-sbox-00-rg --name cft-sbox-00-aks --subscription b72ab7b7-723f-4b18-b6f6-03b0f2c6a1bb --overwrite-existing -a && kubectl config use-context cft-sbox-00-aks-admin
```

Retrieve the existing secret:
```bash
$ kubectl -n kured get secret kured-values  -o jsonpath="{['data']['values\.yaml']}" | base64 -D > /tmp/values.yaml
```
Update this /tmp/values.yaml file with the Slack WebHook for your environment

```bash
ENV=<test>
$ kubectl create secret generic kured-values --from-file=/tmp/values.yaml --namespace kured --dry-run=client -o json > /tmp/values.json
mkdir -p apps/kured/$ENV
mkdir -p apps/kured/$ENV/base
$ kubeseal --format=yaml --cert=clusters/$ENV/pub-cert.pem < /tmp/values.json > apps/kured/$ENV/base/kured-values.yaml
```

### Neuvector
We install Neuvector on prod like or path-to-live environments

It requires a sealed secret that contains the azure storage account name and key

```bash
ENV=<test>
$ STORAGE_ACCOUNT_KEY=$(az keyvault secret show --vault-name cftapps-$ENV --name storage-account-key --query value -o tsv)

$ kubectl create secret generic nv-storage-secret --from-literal azurestorageaccountkey=${STORAGE_ACCOUNT_KEY} --from-literal azurestorageaccountname=cftapps$ENV --namespace neuvector --dry-run=client -o json > /tmp/neuvector.json
$ kubeseal --format=yaml --cert=clusters/$ENV/pub-cert.pem < /tmp/neuvector.json > apps/neuvector/$ENV/base/nv-storage-secret.yaml
```

#### Neuvector logging to Log Analytics

We use fluentbit to ship logs to a Log Analytics workspace

It requires a sealed secret that contains the workspace id and key in it

This can only be retrieved from powershell or lots of clicking in the Azure Portal
The "CustomerId" is your workspace ID
```powershell
ENV=<test>
Connect-AzAccount
Select-AzSubscription DCD-CNP-DEV # prod: DCD-CNP-PROD, sandbox, DCD-CFT-Sandbox
$oms = Get-AzOperationalInsightsWorkspace -ResourceGroupName oms-automation
$workspaceId = $oms.CustomerId.Guid

$keys = Get-AzOperationalInsightsWorkspaceSharedKey -ResourceGroupName oms-automation -Name hmcts-nonprod # prod: hmcts-prod, sandbox: hmcts-sandbox
$primaryKey = $keys.PrimarySharedKey

kubectl create secret generic fluentbit-log --from-literal azure_log_workspace_id=$workspaceId --from-literal azure_log_workspace_shared_key=$primaryKey --namespace neuvector --dry-run=client -o json > /tmp/fluentbit-log.json
```

```bash
kubeseal --format=yaml --cert=clusters/$ENV/pub-cert.pem < /tmp/fluentbit-log.json > apps/neuvector/$ENV/base/fluentbit-log.yaml
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
ENV=<test>
kubectl create secret generic traefik-values --namespace=admin --from-file=values.yaml=tmp/values.yaml --dry-run=client -o yaml > tmp/traefiksecret.yaml
mkdir -p apps/admin/traefik/$ENV
mkdir -p apps/admin/traefik/$ENV/base
kubeseal --format=yaml --cert=apps/<env>/pub-cert.pem <  tmp/traefiksecret.yaml >  apps/admin/traefik/$ENV/base/traefik-values.yaml
```

In demo, traefik-forward-auth is using the following sealed secret:

[oauth2-cert-key.yaml](../k8s/demo/common/sealed-secrets/oauth2-cert-key.yaml)

 this can be generated starting from the .crt and .key files obtained after running openssl on the .pfx file:

```bash
openssl pkcs12 -in ${SECRET_NAME}.pfx -nokeys -nodes -passin pass:"" > demo-platform-hmcts-crt.pem
openssl pkcs12 -in ${SECRET_NAME}.pfx -nocerts -nodes -passin pass:"" > demo-platform-hmcts-key.pem

kubectl create secret generic oauth2-cert-key --from-file demo-platform-hmcts-crt.pem --from-file demo-platform-hmcts-key.pem --namespace admin --dry-run -o json > oauth2-cert-key.json

kubeseal --format=yaml --cert=env/$ENV/pub-cert.pem < oauth2-cert-key.json > apps/admin/$ENV/base/oauth2-cert-key.yaml

rm oauth2-cert-key.json
```

### Kube-Slack
To add Kube-Slack for Slack monitoring on AKS cluster, change the SLACK_CHANNEL in HelmRelease to env specific slack channel.

Log into sandbox as an admin:
```
$ az aks get-credentials --resource-group cft-sbox-00-rg --name cft-sbox-00-aks --subscription b72ab7b7-723f-4b18-b6f6-03b0f2c6a1bb --overwrite-existing -a && kubectl config use-context cft-sbox-00-aks-admin
```

Retrieve the existing secret:
```bash
$ kubectl -n admin get secret kube-slack-values  -o jsonpath="{['data']['values\.yaml']}" | base64 -D > /tmp/values.yaml
```
Update this /tmp/values.yaml file with the Slack WebHook for your environment

Run (replace `<env>` with your env name ):
```bash
ENV=<test>
$ kubectl create secret generic kube-slack-values --from-file=/tmp/values.yaml --namespace admin --dry-run=client -o json > /tmp/values.json
$ kubeseal --format=yaml --cert=apps/$ENV/pub-cert.pem < /tmp/values.json > apps/admin/$ENV/base/kube-slack-values.yaml
```

### Azure DevOps

Only complete this step for management clusters

```bash
ENV=mgmt-sandbox
AZ_DEVOPS_TOKEN=$(az keyvault secret show --vault-name infra-vault-nonprod --name azure-devops-token --query value -o tsv)
kubectl create secret generic vsts-token --from-literal=token=$AZ_DEVOPS_TOKEN --namespace vsts --dry-run=client -o json > /tmp/values.json
mkdir -p k8s/$ENV/common/vsts/
kubeseal --format=yaml --cert=k8s/$ENV/pub-cert.pem < /tmp/values.json > apps/vsts/$ENV/base/vsts-token.yaml
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

kubeseal --format=yaml --cert=apps/$ENV/pub-cert.pem < /tmp/external-dns.json > apps/$ENV/base/external-dns.yaml
```