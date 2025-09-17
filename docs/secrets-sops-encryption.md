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
# How to Edit SOPS-Encrypted Files with Azure Key Vault

This guide shows how to edit SOPS-encrypted files while preserving the Azure Key Vault configuration.

## Prerequisites

- SOPS installed (`brew install sops`)
- yq installed (`brew install yq`)
- Azure CLI authenticated with access to the Key Vault
- Proper permissions to the Azure Key Vault and SOPS key

## Steps to Edit Encrypted Values

### Step 1: Extract the current values for editing

```bash
sops --decrypt <your-secret-file>.yaml | yq '.data."<data-key>"' | base64 -d > values-to-edit.yaml
```

**Example:**
```bash
sops --decrypt backstage-values.yaml | yq '.data."values.yaml"' | base64 -d > values-to-edit.yaml
```

This command:
- Decrypts the SOPS file
- Extracts the specified data field (e.g., `values.yaml`)
- Decodes the base64 content
- Saves it to `values-to-edit.yaml` for editing

### Step 2: Edit the values file

Open and edit the extracted values:

```bash
# Use your preferred editor
nano values-to-edit.yaml
# OR
code values-to-edit.yaml
# OR
vim values-to-edit.yaml
```

Make your changes to the YAML content (secrets, configuration, etc.).

### Step 3: Create updated version with new values

```bash
sops --decrypt <your-secret-file>.yaml > temp-decrypted.yaml
NEW_BASE64=$(base64 -i values-to-edit.yaml)
yq ".data.\"<data-key>\" = \"$NEW_BASE64\"" temp-decrypted.yaml > temp-updated.yaml
```

**Example:**
```bash
sops --decrypt backstage-values.yaml > temp-decrypted.yaml
NEW_BASE64=$(base64 -i values-to-edit.yaml)
yq ".data.\"values.yaml\" = \"$NEW_BASE64\"" temp-decrypted.yaml > temp-updated.yaml
```

This:
- Creates a decrypted copy of the original file
- Encodes your edited values back to base64
- Updates the decrypted file with the new base64 content

### Step 4: Get the Azure Key Vault configuration from the original file

First, extract the Azure Key Vault configuration from your original SOPS file:

```bash
# Get the vault URL, key name, and key version from the original file
VAULT_URL=$(grep -A 5 "azure_kv:" <your-secret-file>.yaml | grep "vault_url:" | awk '{print $3}')
KEY_NAME=$(grep -A 5 "azure_kv:" <your-secret-file>.yaml | grep "name:" | awk '{print $2}')
KEY_VERSION=$(grep -A 5 "azure_kv:" <your-secret-file>.yaml | grep "version:" | awk '{print $2}')

echo "Vault URL: $VAULT_URL"
echo "Key Name: $KEY_NAME" 
echo "Key Version: $KEY_VERSION"
```

**Example:**
```bash
VAULT_URL=$(grep -A 5 "azure_kv:" backstage-values.yaml | grep "vault_url:" | awk '{print $3}')
KEY_NAME=$(grep -A 5 "azure_kv:" backstage-values.yaml | grep "name:" | awk '{print $2}')
KEY_VERSION=$(grep -A 5 "azure_kv:" backstage-values.yaml | grep "version:" | awk '{print $2}')
```

### Step 5: Encrypt with the original Azure Key Vault configuration

```bash
sops --encrypt --azure-kv ${VAULT_URL}/keys/${KEY_NAME}/${KEY_VERSION} --encrypted-regex "^(data|stringData)$" --in-place temp-updated.yaml
```

**Important:** This step uses the exact Azure Key Vault URL and key version from the original file. Different environments use different Key Vaults, so always extract these values from the original file. (e.g `dtscftptlsbox`, `dcdftappssboxkv`, etc.)

### Step 6: Replace the original file and verify

```bash
cp temp-updated.yaml <your-secret-file>.yaml
```

**Example:**
```bash
cp temp-updated.yaml backstage-values.yaml
```

### Step 7: Verify Azure Key Vault configuration is preserved

```bash
grep -A 5 "azure_kv:" <your-secret-file>.yaml
```

You should see output similar to:
```yaml
    azure_kv:
        - vault_url: https://dtscftptlsbox.vault.azure.net
          name: sops-key
          version: b8a4ffea7a5041318ec2d7623a298d0c
```

**Note:** The vault URL will vary by environment and the specific Key Vault configured for that environment. (e.g., `dtscftptlsbox`, `dcdftappssboxkv`, etc)

### Step 8: Clean up temporary files

```bash
rm temp-decrypted.yaml temp-updated.yaml values-to-edit.yaml
```

## Key Points

1. **Always extract the Azure Key Vault configuration** from the original file since different environments use different Key Vaults
2. **Use the exact key version** from the original file (found in the `azure_kv` section) 
3. **Include the `--encrypted-regex` flag** to encrypt only the data fields
4. **Verify the Azure KV config is preserved** before committing changes
5. **Replace placeholders** with your actual file names and data keys:
   - `<your-secret-file>.yaml` → your actual secret file name
   - `<data-key>` → your actual data key (e.g., `values.yaml`, `config.yaml`, etc.)

## Alternative: Direct SOPS Editing

For simple edits, you can also use:

```bash
sops <your-secret-file>.yaml
```

This opens the file directly in your editor with automatic decryption/encryption, but you'll need to manually decode/encode the base64 values within the editor.

## Troubleshooting

- If the `azure_kv` section becomes empty (`azure_kv: []`), you forgot to specify the `--azure-kv` parameter in step 5
- If you get authentication errors, ensure you're logged into Azure CLI and have access to the Key Vault
- If the key version is different, check the original file's SOPS metadata for the correct version
- Replace all placeholder values (`<your-secret-file>`, `<data-key>`) with your actual file and key names
