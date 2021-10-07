
# Application Configuration

>Note: Depending on the [Migration Status](/README.md#Migration status) and the environment you are adding config, you should also do [v2 setup](app-deployment-v2.md)

The section covers how to configure a new application in this repository to deploy to various environments. We use [kustomize](https://github.com/kubernetes-sigs/kustomize) for templating/patching manifests in this repo. 

**It is important to follow below discussed naming convention, file and folder names should match application helm release name**

Note: Some of these scripts need you to [install yq](https://mikefarah.gitbook.io/yq/)

## Namespace

All the applications owned by a team are deployed to a single namespace (usually team name, e.g. probate).

### Create a namespace manifest

- Run [add-namespace.sh](/bin/add-namespace.sh) with your namespace and team build notices slack channel.
   ```bash
    ./bin/add-namespace.sh <your namespace> <team slack channel>
   ```
   
### Add kustomization to a environment

- Run [add-namespace-to-env.sh](/bin/add-namespace-to-env.sh) with namespace, environment and Azure AD team group name (note:- add double quotes for aad_team_group_name).
   ```bash
    ./bin/add-namespace-to-env.sh <your namespace> <environment> <"aad_team_group_name">
   ```

## Managed Identity 

We use Managed Identity to access keyvaults secrets in application.

- Run [base-ns-id-gen.sh](/bin/base-ns-id-gen.sh) with your namespace, Team short name, Manage Identity Name

 ```bash
    ./bin/base-ns-id-gen.sh <your namespace> <team short name> <mi name>
    #example
    ./bin/base-ns-id-gen.sh divorce div div
   ```
- Preview applications use AAT key vaults and thus AAT managed identities, you can reuse identity created for AAT by adding it to preview kustomization.
  Add `- ../../../aat/common/<your-namespace>/identity.yaml` to `bases:` in `k8s/preview/common-overlay/<your namespace>/kustomization.yaml`

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

- Add `- ../../../namespaces/<your-namespace>/<application-name>/<application-name>.yaml`  to `bases:` list in team specific overlay in corresponding environment `/k8s/<env>/common-overlay/<your-namespace>/kustomization.yaml`.

### Override Environment specific config

- If you want to override environment specific config, you need to create patch `<env>.yaml` in `/k8s/namespaces/<your-namespace>/<application-name>/` directory by specifying only the values you want to override.
   [Example prod patch](/k8s/namespaces/rpe/draft-store-service/prod.yaml)
- Add this patch `- ../../../namespaces/<namespace>/<application-name>/prod.yaml` in team specific overlay in corresponding environment `/k8s/<env>/common-overlay/<your-namespace>/kustomization.yaml`.

### Deploy non prod image to an environment

- Image automation responsibility has been moved to flux v2. Please refer to steps detailed [here.](/docs/app-deployment-v2.md#deploy-non-prod-image-to-an-environment)


### Deploying an app to single cluster

- It is recommended to add all applications to both clusters as one of the cluster can be removed from operation at any point. 
- If you still have a use case, it has to be dealt exceptionally with help of [#rpe](https://hmcts-reform.slack.com/archives/C8SR5CAMU)

## Additional details

- Each team has a base kustomization in [namespaces directory](/k8s/namespaces)
- Team's Base kustomization has an overlay with optional patches in [each environment](/k8s/prod/common-overlay/rpe)
- Team's overlays are added to [environment kustomization](/k8s/prod/common-overlay/kustomization.yaml)
- [Environment Kustomization](/k8s/prod/common-overlay/kustomization.yaml) also patches environment specific [global values](/k8s/prod/common-overlay/prod-helmrelease.yaml) and  [image automation defaults](/k8s/prod/common-overlay/automated-helmrelease.yaml).
- Flux image automation is managed through [custom image automation script](/k8s/scripts/container-update.sh)
- prod-* image updates are updated/committed to base manifest where as the other updates(if configured by teams) are applied to environment specific patches.

## Testing in Local

If you want to find the effective yaml that will get applied to a environment, you can [install kustomize](https://kubernetes-sigs.github.io/kustomize/installation/)  and run build commands.

- To generate the effective yaml generated by your namespace in an env, you can run  
  
  `Note : This won't include platform defaults)`
  ```bash
  kustomize build --load_restrictor none k8s/<env>/common-overlay/<your-namespace>
  
  #version 4.x
  kustomize build --load-restrictor LoadRestrictionsNone k8s/<env>/common-overlay/<your-namespace>
  ```
- To generate the effective yaml generated including platform default, you can run 

  `Note : This can be very big as it includes all namespaces, you can temporarily remove other namespaces from bases: in k8s/<env>/common-overlay/kustomization.yaml to make it readable)`
    ```bash
    kustomize build --load_restrictor none k8s/<env>/common-overlay

    #version 4.x
    kustomize build --load-restrictor LoadRestrictionsNone k8s/<env>/common-overlay

    ```
