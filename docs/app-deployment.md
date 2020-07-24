# Application Configuration

The section covers how to configure a new application in this repository to deploy to various environments.
We use [kustomize](https://github.com/kubernetes-sigs/kustomize) for templating/patching manifests in this repo. 

Note: Some of these scripts need you to [install yq](https://mikefarah.gitbook.io/yq/)

## Namespace

All the applications owned by a team are deployed to a single namespace ( usually team name).

## Managed Identity 

We use Managed Identity to access keyvaults secrets in application.

- Run [base-ns-id-gen.sh](/bin/base-ns-id-gen.sh) with your namespace, Team short name, Manage Identity Name

 ```bash
    ./bin/base-ns-id-gen.sh <your namespace> <team short name> <mi name>
    #example
    ./bin/base-ns-id-gen.sh divorce div div
   ```
 
### Create a namespace manifest

- Run [add-namespace.sh](/bin/add-namespace.sh) with your namespace and team build notices slack channel.
   ```bash
    ./bin/add-namespace.sh <your namespace> <team slack channel>
   ```
   
### Add kustomization to a environment

- Run [add-namespace-to-env.sh](/bin/add-namespace-to-env.sh) with namespace and environment.
   ```bash
    ./bin/add-namespace-to-env.sh <your namespace> <environment>
   ```

## Application

All application deployments are managed with `HelmRelease`.

### Add an application manifest

- Standard naming convention for your application (`<application-name>`) is `<product>-<component>`. 
- Add a `HelmRelease` manifest in `/k8s/namespaces/<your-namespace>/<application-name>/<application-name>.yaml`. [See example](/k8s/namespaces/rpe/draft-store-service/draft-store-service.yaml)


### Add application to all environments

Below adds Application to all the environments you have [added your kustomization](#Add-kustomization-to-a-environment). 
If you want to add a new app only to a one environment, see [Add application to only one environment](#Add-application-to-only-one-environment)

- Add `- <application-name>/<application-name>.yaml`  to `bases:` list in `/k8s/namespaces/<your-namespace>/kustomization.yaml`

### Add application to only one environment

- Add `- ../../../<application-name>/<application-name>.yaml`  to `bases:` list in team specific overlay in corresponding environment `/k8s/<env>/common-overlay/<your-namespace>/kustomization.yaml`.

### Override Environment specific config

- If you want to override environment specific config, you need to create patch `<env>.yaml` in `/k8s/namespaces/<your-namespace>/<application-name>/` directory by specifying only the values you want to override.
   [Example prod patch](/k8s/namespaces/rpe/draft-store-service/prod.yaml)
- Add this patch `- ../../../namespaces/<namespace>/<application-name>/prod.yaml` in team specific overlay in corresponding environment `/k8s/<env>/common-overlay/<your-namespace>/kustomization.yaml`.

### Deploy non prod image to an environment

- The default setup is configured to set all environments with image automation enabled with `prod-*` tag.
- It is highly recommended to follow trunk based development, use prod image on all environments using feature toggling.
- **It is not allowed to break prod image automation on `aat` and `prod`.**
- If you wish to override this default behaviour in a specific environment, create a environment patch as described in previous section and set image automation annotations as in below example: 
```yaml
---
apiVersion: helm.fluxcd.io/v1
kind: HelmRelease
metadata:
  name: <application-name>
  annotations:
    fluxcd.io/automated: "true"
    fluxcd.io/tag.(java/nodejs): glob:pr-112-*
    hmcts.github.com/prod-automated: disabled
....
....
```

### Deploying an app to single cluster

- It is recommended to add all applications to both clusters as one of the cluster can be removed from operation at any point. 
- If you still have a use case, it has to be dealt exceptionally with help of [#rpe](https://hmcts-reform.slack.com/archives/C8SR5CAMU)