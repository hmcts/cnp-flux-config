
# Application Configuration

>Note: Only use for Flux v2 applications

The section covers how to configure a new application in this repository to deploy to various environments. We use [kustomize](https://github.com/kubernetes-sigs/kustomize) for templating/patching manifests in this repo. 

**It is important to follow below discussed naming convention, file and folder names should match application helm release name**

Note: You need to [install yq](https://mikefarah.gitbook.io/yq/) for these scripts

## Namespace

All the applications owned by a team are deployed to a single namespace (usually team name, e.g. probate).

### Create a namespace manifest

- Run [add-namespace.sh](/bin/v2/add-namespace.sh) with your namespace and team build notices slack channel.
   ```bash
    ./bin/v2/add-namespace.sh <your namespace> <team slack channel>
   ```
   
### Add namespace kustomization to an environment

- Run [add-namespace-to-env.sh](/bin/v2/add-namespace-to-env.sh) with namespace, environment.
   ```bash
    ./bin/v2/add-namespace-to-env.sh <your namespace> <environment>
   ```

## Managed Identity

We use Managed Identity to access keyvaults secrets in application. This should be created after namespace is created above.

### Create a managed identity base

- Run [add-identity-base.sh](/bin/v2/add-identity-base.sh) with your namespace, Team short name

 ```bash
    ./bin/v2/add-identity-base.sh <your namespace> <team short name>
    #example
    ./bin/v2/add-identity-base.sh divorce div
   ```
### Add managed identity to an environment

- Please note Preview applications use AAT key vaults and thus AAT managed identities, you can reuse identity created for AAT by adding it to preview kustomization.

- Run [add-identity-to-env.sh](/bin/v2/add-identity-to-env.sh) with your namespace, Team short name, MI name, environment

 ```bash
    ./bin/v2/add-identity-to-env.sh <your namespace> <team short name> <mi name> <environment>
    #example
    ./bin/v2/add-identity-to-env.sh divorce div div aat
   ```

## Application

All application deployments are managed with `HelmRelease`.

### Add a new application

- Standard naming convention for your application (`<application-name>`) is `<product>-<component>`. 
- Add a `HelmRelease` manifest in `apps/<your-namespace>/<application-name>/<application-name>.yaml`. [See example](/apps/rpe/draft-store-service/draft-store-service.yaml)
- Run [add-image-policies.sh](/bin/v2/add-image-policies.sh) with your namespace, product,component

 ```bash
    ./bin/v2/add-image-policies.sh <your namespace> <product> <component>
    #example
    ./bin/v2/add-image-policies.sh divorce div frontend
   ```
- Add a comment next to `image` section in HelmRelease with ImagePolicy name as shown below.
    ```yaml
    apiVersion: helm.toolkit.fluxcd.io/v2beta1
    kind: HelmRelease
    metadata:
      name: <component-name>
    spec:
      releaseName: <component-name>
      values:
        java:
          image: hmctspublic.azurecr.io/<product>/<component>:<latest prod tag>   #{"$imagepolicy": "flux-system:<component-name>"}
          #Example below
          #image: hmctspublic.azurecr.io/draft-store/service:prod-c7a879d-20210807222025   #{"$imagepolicy": "flux-system:draft-store-service"}
    ```

### Add application to all environments

Below adds Application to all the environments you have [added your namespace kustomization](#Add-namespace-kustomization-to-an-environment). 
If you want to add a new app only to a one environment, see [Add application to only one environment](#Add-application-to-only-one-environment)

- Add `- ../<application-name>/<application-name>.yaml`  to `resources:` list in `/apps/<your-namespace>/base/kustomization.yaml`

### Add application to only one environment

- Add `- ../../<application-name>/<application-name>.yaml`  to `resources:` list in namespace env overlay in corresponding environment `/apps/<your-namespace>/<env>/base/kustomization.yaml`.

### Override Environment specific config

- If you want to override environment specific config, you need to create patch `<env>.yaml` in `/apps/<your-namespace>/<application-name>/` directory by specifying only the values you want to override.
   [Example prod patch](/apps/rpe/draft-store-service/prod.yaml)
- Add this patch `- ../../<application-name>/<env>.yaml` to `patchesStrategicMerge` list in team specific overlay in corresponding environment `/apps/<your-namespace>/<env>/base/kustomization.yaml`.

### Deploy non prod image to an environment

- The default setup is configured to set all environments with image automation enabled with `prod-*` tag.
- It is highly recommended to follow trunk based development, use prod image on all environments using feature toggling.
- **It is not allowed to break prod image automation on `aat` and `prod`.**
- If you wish to override this default behaviour in a specific environment, create a environment patch as described in the previous section and override image automation comment like below: 

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: <component-name>
spec:
  values:
    java:
      image: hmctspublic.azurecr.io/<product>/<component>:<latest pr-123-tag>   #{"$imagepolicy": "flux-system:<env>-<component-name>"}
      #Example below
      #image: hmctspublic.azurecr.io/draft-store/service:pr-123-20210807222025   #{"$imagepolicy": "flux-system:demo-draft-store-service"}
```

- Create an image policy like below (or update an existing environment image policy) with your pr number (pr-332 taken as example) along side your HelmRelease file.

```yaml
apiVersion: image.toolkit.fluxcd.io/v1alpha2
kind: ImagePolicy
metadata:
  name: <env>-<component-name>
  annotations:
    hmcts.github.com/prod-automated: disabled
spec:
  filterTags:
    pattern: '^pr-332-[a-f0-9]+-(?P<ts>[0-9]+)'
    extract: '$ts'
  policy:
    alphabetical:
      order: asc
  imageRepositoryRef:
    name: <component-name>
```
- Add `- ../<component-name>/<env>-image-policy.yaml` to `resources` in automation kustomization `apps/<your-namespace>/automation/kustomization.yaml`

### Remove a non prod image deployment from an environment

- If an [environment using a non prod image](#Deploy-non-prod-image-to-an-environment) requires changing to use the prod image, update the HelmRelease patch to change the image policy marker to the default as in the example below
```yaml
#From:
image: hmctspublic.azurecr.io/draft-store/service:pr-123-20210807222025   #{"$imagepolicy": "flux-system:demo-draft-store-service"}

#To:
image: hmctspublic.azurecr.io/draft-store/service:pr-123-20210807222025   #{"$imagepolicy": "flux-system:draft-store-service"}
```
- Alternatively, delete the HelmRelease patch if it does not contain any required patches and  
  - Delete the existing environment image policy file `<component-name>/<env>-image-policy.yaml` 
  - Delete the entry `- ../<component-name>/<env>-image-policy.yaml` from `resources` in automation kustomization `apps/<your-namespace>/automation/kustomization.yaml`

### Deploying an app to single cluster

- It is recommended to add all applications to both clusters as one of the cluster can be removed from operation at any point. 
- If you still have a use case, it has to be dealt exceptionally with help of [platops](https://hmcts-reform.slack.com/archives/C8SR5CAMU)

## Testing in Local

If you want to find the effective yaml that will get applied to an environment for your namespace, you can [install kustomize](https://kubernetes-sigs.github.io/kustomize/installation/) and run build commands.

- To generate the effective yaml generated by your namespace in an env, you can run  
  
  `Note : This won't include platform defaults and env substitutions)`
  ```bash
  kustomize build --load_restrictor none apps/<namespace>/<env>/base
  
  #version 4.x
  kustomize build --load-restrictor LoadRestrictionsNone apps/<namespace>/<env>/base
  ```