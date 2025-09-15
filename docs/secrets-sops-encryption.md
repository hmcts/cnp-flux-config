## Secrets SOPS Encryption

Install sops:
```
brew install sops
```

## Create a Kubernetes Secret (Unencrypted):

The following is an example for kube-prometheus-stack:

In your Helm File: apps/monitoring/kube-prometheus-stack/kube-prometheus-stack.yaml
you will define what the secret file name for kube-prometheus-stack is looking for, here is an example:
```
  valuesFrom:
    - name: "prometheus-values"
      kind: Secret
```

Create a file called values.yaml in a temporary folder e.g. /tmp on macOS, Linux
  Enter your Secrets:

Example secret
```
extraArgs:
  slack-hook-url: https://hooks.slack.com/services/11111111111111111111/22222222222222
```

Create the secret:
```
 kubectl create secret generic prometheus-values -n monitoring --from-file=values.yaml --type=Opaque -o yaml --dry-run=client > prometheus-values.enc.yaml
```

Your prometheus-values.enc.yaml content will look like this, note the secret value is encoded in base64:
```
apiVersion: v1
data:
  values.yaml: ZXh0cmFBcmdzOgogIHNsYWNrLWhvb2stdXJsOiBodHRwczovL2hvb2tzLnNsYWNrLmNvbS9zZXJ2aWNlcy8xMTExMTExMTExMTExMTExMTExMS8yMjIyMjIyMjIyMjIyMg==
kind: Secret
metadata:
  creationTimestamp: null
  name: prometheus-values
  namespace: monitoring
type: Opaque
```

## Encrypt Kubernetes Secret (from step 1):

You want to use the kv that matches your environment.
The number after sops-key is the CURRENT VERSION this can be found in azure keyvault under keys/sops-key.
```
sops --encrypt --azure-kv https://dcdcftappssboxkv.vault.azure.net/keys/sops-key/4dfa9dd4b0444f03bd64e2128e347537 --encrypted-regex "^(data|stringData)$" --in-place prometheus-values.enc.yaml
```
Once created place it in apps environment folder.

example for kube-prometheus-stack: app/monitoring/kube-prometheus-stack/sbox
```
apiVersion: v1
data:
    values.yaml: ENC[AES256_GCM,data:T09iEDGkyDvnS+FoRcta5LBd7rQ2BzRAMZZZ1IOacI+i2cJsEkqLpXRdjeciULwCo8QW4ZR7mQAnba+XXOfHQWi7hgxMYIrEMxnvJfk62TmvkEA0TwQZ70Z8FA0ejdhWEgskyAUONdbX1iUW6iumozLW2ZLS/3KKVA7FM6GgrZ3d3yTO,iv:ylqBrVTTUJEnn4UVsqWUUOpzoHNUHBDdo71Ym22GahA=,tag:vUsDzdlpgnOhfYcqDsnsMg==,type:str]
kind: Secret
metadata:
    creationTimestamp: null
    name: prometheus-values
    namespace: monitoring
type: Opaque
sops:
    kms: []
    gcp_kms: []
    azure_kv:
        - vault_url: https://dcdcftappssboxkv.vault.azure.net
          name: sops-key
          version: 4dfa9dd4b0444f03bd64e2128e347537
          created_at: "2023-02-17T14:43:08Z"
          enc: BS87SC3O3QC6wUczjfuLjO1FGyxFz45w9mgeEsSWsfdGwHacz8kBCmBmAFfrXeX146T-Rrvk1W8W4pJ49A7nwsO_PWNeNhQkHEkH2eTGWckGf6gCd_6KsNDDTVikXg5fg3AHJH6ph3kByLE05QysAmvFPxKkLoM8E4kylxT2ieIcLB9ABsh1BcEXzUDeEHlUuTszXG6vp_AfF9qHBZGxQenPM9vxQywq3wX60ytBF4ej1mW7j_xRqGuIKZW_XQ7Q1623R5DCJ1p-2tZE4mEDTPM32BhblynIm19d3qC2tGwsgUOqkvr-gJzWN6V-FeFk-6hm5GL4zhO0-W_bi7g2lg
    hc_vault: []
    age: []
    lastmodified: "2023-02-17T14:43:09Z"
    mac: ENC[AES256_GCM,data:1z9LF4Tm6SW82mbgONEHtJAlzvqrL5J+Kp1tG2ECAaT8eKzo4t5qRCjRKNT9nojPgHedyas6rL8NnqsnQXrtT4PLVDnHOn5Y1j3dw4l9ilMGhpRRtkn4upptaVH+T3p+IPhCDCd829O0EskO2wWBln6sv19HuQsOHnSfQSRxFw0=,iv:So68LTzJK72jE5Wk1S7jxaJtug9rjEp8kEQpEumzqUY=,tag:K5dQtAX3im8BFahWm/ppQw==,type:str]
    pgp: []
    encrypted_regex: ^(data|stringData)$
    version: 3.7.3
```
You then need to edit the Kustomization.yaml file which corresponds with your environment adding prometheus-values.enc.yaml to the resources section.
example: apps/monitoring/sbox/base
```
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../base
  - ../../kube-prometheus-stack/sbox/prometheus-values.enc.yaml
namespace: monitoring
```

You can then delete the Values.yaml file from the directory

Commit your changes.

If you ever need to decrypt the file e.g. to update the secret value or change the secret name, you can use something like the command below:

```
sops --decrypt --in-place prometheus-values.enc.yaml
```

The file output by SOPS will encode the secret in base64. You can get the plaintext value of the secret by decoding it:

```
echo $MY_SECRET | base64 -d
extraArgs:
  slack-hook-url: https://hooks.slack.com/services/11111111111111111111/22222222222222
```

## Extract, Update and Re-encrypt Existing SOPS Secrets:

If you need to update an existing encrypted secret, follow these steps:

### Step 1: Extract the current base64 encoded values

First, you need to get the current key version from Azure Key Vault:
```
az keyvault key show --vault-name dcdcftappssboxkv --name sops-key --query "key.kid"
```

Extract the base64 encoded values.yaml content from the encrypted secret:
```
sops --decrypt prometheus-values.enc.yaml | yq '.data."values.yaml"' | base64 -d > /tmp/current-values.yaml
```

### Step 2: Edit the values

Edit the extracted values file with your preferred editor:
```
code /tmp/current-values.yaml
# or vim, nano, etc.
```

Example of editing the slack webhook URL:
```
extraArgs:
  slack-hook-url: https://hooks.slack.com/services/NEW_WEBHOOK_URL_HERE
```

### Step 3: Re-encode and update the secret

Decrypt the original encrypted file temporarily:
```
sops --decrypt prometheus-values.enc.yaml > /tmp/temp-secret.yaml
```

Update the values.yaml field in the temporary file with the new base64 content:
```
yq eval ".data.\"values.yaml\" = \"$(base64 -i /tmp/current-values.yaml)\"" -i /tmp/temp-secret.yaml
```

### Step 4: Re-encrypt the updated secret

Re-encrypt the file using the current key version (replace the version number with the one from Step 1):
```
sops --encrypt --azure-kv https://dcdcftappssboxkv.vault.azure.net/keys/sops-key/4dfa9dd4b0444f03bd64e2128e347537 --encrypted-regex "^(data|stringData)$" --in-place /tmp/temp-secret.yaml
```

Copy the re-encrypted content back to your original file:
```
cp /tmp/temp-secret.yaml prometheus-values.enc.yaml
```

### Step 5: Clean up temporary files

Remove the temporary files:
```
rm /tmp/current-values.yaml /tmp/temp-secret.yaml
```

### Alternative: Direct SOPS editing

For simpler updates, you can also edit the encrypted file directly with SOPS (this will handle decryption/encryption automatically):
```
sops prometheus-values.enc.yaml
```

Note: When using direct SOPS editing, the values.yaml field will still be base64 encoded. You'll need to manually decode/encode the content within that field.
